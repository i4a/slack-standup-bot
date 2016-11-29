class IncomingMessage

  STANDUP_STATUS = { in_progress: 0, done: 1 }

  delegate :yes?, :vacation?, :skip?, :status?, :postpone?, :quit?, :edit?, :delete?,
           :help?, :not_available?, :unavailable?, :start?, to: :message_type

  # @param [Hash] message.
  # @option message [String] :type.
  # @option message [String] :channel.
  # @option message [String] :user.
  # @option message [String] :text.
  def initialize(message)
    @message = message
    @status  = STANDUP_STATUS[:in_progress]
  end

  # Executes incomming message.
  def execute
    return if current_user && (current_user.bot? || (channel.today_standups.empty? && !start?))

    if start? && channel.today_standups.empty?
      start_standup

    elsif command
      command.execute

      if (standup.completed? || standup.idle?) && ![Status, Quit, Help].include?(command.class)
        next_user

      elsif command.kind_of?(Quit)
        @status = STANDUP_STATUS[:done]
      end
    end

  rescue Base::InvalidCommandError => e
    channel.message(e.message)
  end

  # Returns true if the standup session has finished, that means that all the
  #   standup were completed correctly and we can kill the slack realtime client.
  #
  # @return [Boolean]
  def standup_finished?
    @status == STANDUP_STATUS[:done]
  end

  # Creates all the data to start the standup session.
  def start_standup
    channel.start_today_standup!

    if standup.idle?
      standup.init!

      AutoSkip.new(standup.id, standup.updated_at).perform

      channel.message(I18n.t('incoming_message.standup_started'))
      channel.message(I18n.t('incoming_message.welcome', user: current_user.slack_id))
    else
      next_user
    end
  end

  # It sets the next user as the current one, if there are no next users to ask for
  #   the standup, it finishes the standup.
  def next_user
    if standup.channel.complete?
      complete_standup

    elsif (next_standup = channel.pending_standups.first)
      next_standup.init!

      AutoSkip.new(next_standup.id, next_standup.updated_at).perform

      channel.message(I18n.t('incoming_message.welcome', user: next_standup.user_slack_id))
    end
  end

  def complete_standup
    url = Rails.application.routes.url_helpers.channel_standups_url(channel_id: channel.id, host: settings.web_url)
    minutes_elapsed = Standup.time_elapsed_in_todays_standup / 60

    StandupMailer.today_report(channel.id).deliver_later

    channel.message(I18n.t('incoming_message.resume', url: url))

    case
    when minutes_elapsed < channel.great_finish_up_time_in_minutes
      channel.message(I18n.t('incoming_message.resume_time_great', minutes: minutes_elapsed))
    when minutes_elapsed < channel.winter_is_coming_finish_up_time_in_minutes
      channel.message(I18n.t('incoming_message.resume_time_to_improve', minutes: minutes_elapsed))
    else
      channel.message(I18n.t('incoming_message.resume_time_winter_is_coming', minutes: minutes_elapsed))
    end

    @status = STANDUP_STATUS[:done]
  end

  private

  # @return [User]
  def current_user
    User.find_by(slack_id: @message['user'])
  end

  # @return [Standup]
  def standup
    channel.today_standups.where(user_id: current_user.id).first!
  end

  # @return [Channel]
  def channel
    Channel.where(slack_id: @message['channel']).first!
  end

  # @return [Setting]
  def settings
    @settings ||= Setting.first
  end

  # @return [IncomingMessage::Base]
  def command
    return @command if defined?(@command)

    klass =
      if vacation?               then Vacation
      elsif not_available?       then NotAvailable
      elsif unavailable?         then Unavailable
      elsif skip?                then Skip
      elsif postpone?            then Postpone
      elsif quit?                then Quit
      elsif help?                then Help
      elsif edit?                then Edit
      elsif delete?              then Delete
      elsif status?              then Status
      elsif standup.in_progress? then Answer
      end

    @command = klass.new(@message, standup) if klass
  end

  # @return [MessageType]
  def message_type
    @message_type ||= MessageType.new(@message['text'])
  end

end
