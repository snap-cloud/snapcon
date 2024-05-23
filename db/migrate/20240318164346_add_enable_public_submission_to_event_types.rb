class AddEnablePublicSubmissionToEventTypes < ActiveRecord::Migration[7.0]
  def change
    add_column :event_types, :enable_public_submission, :boolean, default: true, null: false
  end
end
