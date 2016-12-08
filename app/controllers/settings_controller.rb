class SettingsController < ApplicationController

  # GET /settings
  def index
    @settings = Setting.first_or_initialize
  end

  def create
    settings = Setting.new(settings_params)

    if settings.save
      redirect_to settings_path, notice: I18n.t('settings.index.success')
    else
      redirect_to settings_path, error: settings.errors.full_messages.split(', ')
    end
  end

  def update
    settings = Setting.find(params[:id])

    if settings.update(settings_params)
      redirect_to settings_path, notice: I18n.t('settings.index.success')
    else
      redirect_to settings_path, error: settings.errors.full_messages.split(', ')
    end
  end

  private

  def settings_params
    params.require(:setting).permit(:name, :bot_id, :bot_name, :web_url, :api_token, :auto_skip_timeout, :skip_weekends)
  end

end
