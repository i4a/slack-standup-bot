namespace :slack_standup_bot do
  desc 'Starts Standup for a given CHANNEL_ID or CHANNEL_NAME'
  task start: :env do
    abort('Please provide either a CHANNEL_ID or a CHANNEL_NAME to start the Standup into') unless ENV['CHANNEL_ID'] || ENV['CHANNEL_NAME']

    channel_id = ENV['CHANNEL_ID'] || Standupbot::Slack::Channel.by_name(ENV['CHANNEL_NAME']).try{ |ch| ch['id'] }

    abort('Please provide a valid CHANNEL_ID or CHANNEL_NAME to start the Standup into') unless channel_id

    client = Standupbot::Client.new(channel_id)

    if client.valid?
      client.start!
    else
      puts 'Could not start the Standup:'
      puts client.errors.inspect
    end
  end
end
