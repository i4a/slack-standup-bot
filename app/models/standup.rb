# == Schema Information
#
# Table name: standups
#
#  id                 :integer          not null, primary key
#  yesterday          :text
#  today              :text
#  conflicts          :text
#  created_at         :datetime
#  updated_at         :datetime
#  channel_id         :integer
#  user_id            :integer
#  order              :integer          default(1)
#  state              :string
#  auto_skipped_times :integer          default(0)
#  reason             :string
#

class Standup < ActiveRecord::Base

  IDLE          = 'idle'
  ACTIVE        = 'active'
  ANSWERING     = 'answering'
  DONE          = 'done'
  NOT_AVAILABLE = 'not_available'
  VACATION      = 'vacation'

  MAXIMUM_AUTO_SKIPPED_TIMES = 2

  belongs_to :user
  belongs_to :channel

  validates :user_id, :channel_id, presence: true

  scope :for, ->(user_id, channel_id) { where(user_id: user_id, channel_id: channel_id) }
  scope :for_channel, ->(channel) { where channel: channel }
  scope :today, -> { where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day) }
  scope :by_date, -> date { where(created_at: date.at_midnight..date.next_day.at_midnight) }

  scope :in_progress, -> { where(state: [ACTIVE, ANSWERING]) }
  scope :active, -> { where(state: ACTIVE) }
  scope :pending, -> { where(state: IDLE) }
  scope :completed, -> { where(state: [DONE, NOT_AVAILABLE, VACATION]) }

  scope :sorted, -> { order(order: :asc) }

  delegate :slack_id, :full_name, to: :user, prefix: true
  delegate :slack_id, to: :channel, prefix: true

  state_machine initial: :idle do

    event :init do
      transition from: :idle, to: :active
    end

    event :skip do
      transition from: :active, to: :idle
    end

    event :start do
      transition from: :active, to: :answering
    end

    event :edit do
      transition from: :done, to: :answering
    end

    event :not_available do
      transition from: :active, to: :not_available
    end

    event :vacation do
      transition from: :active, to: :vacation
    end

    event :finish do
      transition from: :answering, to: :done
    end

    before_transition on: :skip do |standup, _|
      standup.order = (standup.channel.today_standups.maximum(:order) + 1) || 1
    end

  end

  class << self

    # @param [Integer] user_id.
    # @param [Integer] channel_id.
    #
    # @return [Standup]
    def create_if_needed(user_id, channel_id)
      return if User.find(user_id).bot?

      standup = Standup.today.for(user_id, channel_id).first_or_initialize

      standup.save

      standup
    end

    # in seconds
    def time_elapsed_in_todays_standup(channel)
      today_ended_at(channel) - today_started_at(channel)
    end

    def today_started_at(channel)
      for_channel(channel).today.first.try(:created_at)
    end

    def today_ended_at(channel)
      for_channel(channel).today.last.try(:updated_at)
    end

  end

  # @return [Boolean]
  def completed?
    done? || vacation? || not_available?
  end

  # @return [Boolean]
  def in_progress?
    active? || answering?
  end

  def question_for_number(number)
    case number
    when 1 then Time.now.wday == 1 ? I18n.t('standup.question_1_monday') : I18n.t('standup.question_1_not_monday')
    when 2 then I18n.t('standup.question_2')
    when 3 then I18n.t('standup.question_3')
    end
  end

  def current_question
    user = user.slack_id

    if yesterday.nil?
      Time.now.wday == 1 ? I18n.t('standup.current_question_1_monday', user: user) : I18n.t('standup.current_question_1_not_monday', user: user)
    elsif today.nil?
      I18n.t('standup.current_question_2', user: user)
    elsif conflicts.nil?
      I18n.t('standup.current_question_3', user: user)
    end
  end

  def process_answer(answer)
    answer = replace_slack_ids_for_names(answer)

    if self.yesterday.nil?
      self.update_attributes(yesterday: answer)

    elsif self.today.nil?
      self.update_attributes(today: answer)

    elsif self.conflicts.nil?
      self.update_attributes(conflicts: answer)
    end

    if self.yesterday.present? && self.today.present? && self.conflicts.present?
      self.finish!
    end
  end

  def delete_answer_for(question)
    case question
    when 1
      self.update_attributes(yesterday: nil)
    when 2
      self.update_attributes(today: nil)
    when 3
      self.update_attributes(conflicts: nil)
    end
  end

  # Returns the current status of the standup.
  #
  # @return [String]
  def status
    user = self.user.slack_id

    if idle?
      I18n.t('standup.status.idle', user: user)
    elsif active?
      I18n.t('standup.status.active', user: user)
    elsif answering?
      if yesterday.nil?
        I18n.t('standup.status.answering_yesterday', user: user)
      elsif today.nil?
        I18n.t('standup.status.answering_today', user: user)
      else
        I18n.t('standup.status.answering_conflicts', user: user)
      end
    elsif completed?
      if vacation?
        I18n.t('standup.status.on_vacation', user: user)
      elsif not_available?
        I18n.t('standup.status.not_available', user: user)
      else
        I18n.t('standup.status.done', user: user)
      end
    end
  end

  private

  # Replaces all the Slack user ids with the name of those users.
  #
  # @param [String] text.
  # @return [String]
  def replace_slack_ids_for_names(text)
    return text if (user_ids = text.scan(/\<@(.*?)\>/)).blank?

    user_ids.each do |user_id|
      user = User.find_by_slack_id(user_id.first)

      text.gsub!("<@#{user_id.flatten.first}>", (user ? user.full_name : "User Not Available"))
    end

    text
  end

  def settings
    Setting.first
  end

end
