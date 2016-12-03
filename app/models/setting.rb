# == Schema Information
#
# Table name: settings
#
#  id                :integer          not null, primary key
#  name              :string
#  bot_id            :string
#  bot_name          :string
#  web_url           :string
#  api_token         :string
#  auto_skip_timeout :integer          default(2)
#  skip_weekends     :boolean          default(TRUE)
#

class Setting < ActiveRecord::Base

  validates :auto_skip_timeout, presence: true

  def skip_today?
    return false unless skip_weekends?
    Date.today.saturday? || Date.today.sunday?
  end
end
