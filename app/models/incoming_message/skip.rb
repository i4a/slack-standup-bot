require_relative 'compound'

class IncomingMessage
  class Skip < Compound

    def execute
      super

      if @standup.active?
        @standup.skip!

        channel.message(I18n.t('incoming_message.skip.skip', user: @standup.user_slack_id))
      end
    end

    def validate!
      if !user.admin?
        raise InvalidCommandError.new(I18n.t('incoming_message.skip.not_allowed'))
      elsif @standup.idle?
        raise InvalidCommandError.new(I18n.t('incoming_message.skip.need_to_wait', user: reffered_user.slack_id))
      elsif @standup.completed?
        raise InvalidCommandError.new(I18n.t('incoming_message.skip.already_completed', user: reffered_user.slack_id))
      elsif @standup.answering?
        raise InvalidCommandError.new(I18n.t('incoming_message.skip.other_answering', user: reffered_user.slack_id))
      elsif channel.today_standups.pending.empty?
        raise InvalidCommandError.new(I18n.t('incoming_message.skip.last_man_answering'))
      end

      super
    end

  end
end
