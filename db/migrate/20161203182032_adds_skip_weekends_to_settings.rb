class AddsSkipWeekendsToSettings < ActiveRecord::Migration
  def change
    add_column :settings, :skip_weekends, :boolean, default: true
  end
end
