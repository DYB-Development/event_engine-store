class CreateEventEngineStoreStoredEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :event_engine_store_stored_events do |t|
      t.string :event_name, null: false
      t.string :event_type
      t.integer :event_version
      t.string :process_type
      t.json :payload
      t.json :metadata
      t.datetime :occurred_at
      t.string :idempotency_key
      t.string :aggregate_type
      t.string :aggregate_id
      t.integer :aggregate_version
      t.datetime :created_at, null: false
    end

    add_index :event_engine_store_stored_events, :event_name
    add_index :event_engine_store_stored_events, :occurred_at
    add_index :event_engine_store_stored_events, :idempotency_key
  end
end
