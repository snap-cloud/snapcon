class RenameSubmissionInstructionsToSubmissionTemplate < ActiveRecord::Migration[7.0]
  def change
    rename_column :event_types, :submission_instructions, :submission_template
  end
end
