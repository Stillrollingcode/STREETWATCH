class AddCrewToProfileType < ActiveRecord::Migration[8.0]
  def up
    # No database changes needed since profile_type is a string column
    # The enum values are defined in the model, not enforced at the database level
    # This migration just documents the addition of 'crew' as a valid value
  end

  def down
    # Remove 'crew' profile_type if rolling back
    User.where(profile_type: 'crew').update_all(profile_type: 'company')
  end
end
