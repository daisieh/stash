class AddCurrentEditorIdToStashEngineResources < ActiveRecord::Migration
  def change
    change_table :stash_engine_resources do |t|
      t.integer :current_editor_id
      t.index :current_editor_id
    end
  end
end
