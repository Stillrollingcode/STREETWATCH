class CreateDataImports < ActiveRecord::Migration[8.0]
  def change
    create_table :data_imports do |t|
      t.string :import_type # 'users', 'films', 'photos'
      t.string :status, default: 'pending' # pending, processing, completed, failed
      t.integer :total_rows, default: 0
      t.integer :successful_rows, default: 0
      t.integer :failed_rows, default: 0
      t.text :error_log
      t.json :column_mapping # Stores mapping from Excel columns to model attributes
      t.references :admin_user, foreign_key: true

      t.timestamps
    end

    add_index :data_imports, :status
    add_index :data_imports, :import_type
  end
end
