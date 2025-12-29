class UpdateVideoPartToRiderPart < ActiveRecord::Migration[8.0]
  def up
    # Update all existing 'video_part' film types to 'rider_part'
    Film.where(film_type: 'video_part').update_all(film_type: 'rider_part')
  end

  def down
    # Revert 'rider_part' back to 'video_part' if migration is rolled back
    Film.where(film_type: 'rider_part').update_all(film_type: 'video_part')
  end
end
