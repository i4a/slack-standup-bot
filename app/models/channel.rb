# == Schema Information
#
# Table name: channels
#
#  id       :integer          not null, primary key
#  name     :string
#  slack_id :string
#  state    :string           default("idle")
#

require 'standupbot/slack/client'

class Channel < ActiveRecord::Base

  has_many :channel_users
  has_many :users, through: :channel_users
  has_many :standups

  validates :slack_id, :name, presence: true

  state_machine initial: :idle do

    event :start do
      transition from: :idle, to: :active
    end

    event :stop do
      transition from: :active, to: :idle
    end

  end

  STANDUP_COMPLETION_TIMES_PER_USER = {
    great: 3,
    to_improve: 5,
    winter_is_coming: 12
  }

  STANDUP_COMPLETION_TIMES_PER_USER.each do |name, minutes|
    define_method "#{name}_finish_up_time_in_minutes" do
      available_users.count * minutes
    end
  end

  # Returns only the users that are able to do the standup.
  #
  # @return [ActiveRecord::AssociationRelation<Users>]
  def available_users
    self.users.non_bot.enabled
  end

  # Creates all the Standup records.
  #
  def start_today_standup!
    self.transaction do
      available_users.each_with_index do |user, index|
        standup = Standup.create_if_needed(user.id, self.id)

        standup.order= index + 1

        standup.save
      end
    end
  end

  # Returns all the standups of today.
  #
  # @return [ActiveRecord::AssociationRelation<Standup>]
  def today_standups
    self.standups.today
  end

  # Returns the standups that weren't done yet.
  #
  # @return [ActiveRecord::AssociationRelation<Standup>]
  def pending_standups
    today_standups.pending.sorted
  end

  # @return [Standup]
  def current_standup
    today_standups.in_progress.first
  end

  # @return [Boolean]
  def complete?
    today_standups.any? && today_standups.completed.count == today_standups.count
  end

  # Sends a message to the slack channel.
  #
  # @param [String] text.
  def message(text)
    slack_client.message(text)
  end

  private

  # @return [Standupbot::Slack::Client]
  def slack_client
    @slack_client ||= Standupbot::Slack::Client.new(self)
  end

end
