require 'standupbot/client'
require 'standupbot/slack/channel'

namespace :slack_standup_bot do
  desc 'Starts Standup for a given CHANNEL_ID or CHANNEL_NAME'
  task start: :environment do
    abort('Please provide either a CHANNEL_ID or a CHANNEL_NAME to start the Standup into') unless ENV['CHANNEL_ID'] || ENV['CHANNEL_NAME']

    channel_id = ENV['CHANNEL_ID'] || Standupbot::Slack::Channel.by_name(ENV['CHANNEL_NAME']).try{ |ch| ch['id'] }

    abort('Please provide a valid CHANNEL_ID or CHANNEL_NAME to start the Standup into') unless channel_id

    setting = Setting.last
    params = {
      format: 'text',
      channel_id: channel_id
    }

    start_url = "#{setting.web_url}/api/standups/start?#{params.to_query}"
    `curl #{start_url}`
  end
end
