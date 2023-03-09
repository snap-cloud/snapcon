class AddPresentationModeToEvent < ActiveRecord::Migration[7.0]
  def up
    # note that enums cannot be dropped
    create_enum :presentation_mode, ["in person", "online"]

    change_table :events do |t|
      t.enum :presentation_mode, enum_type: "presentation_mode", null: true
    end
  end
end
