class AddCurrentCurationActivityIdToStashEngineIdentifiers < ActiveRecord::Migration
  def change
    add_column :stash_engine_identifiers, :current_curation_activity_id, :integer
    add_index :stash_engine_identifiers, :current_curation_activity_id
  end
end
