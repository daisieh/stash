class DropStashEngineIdentifierStates < ActiveRecord::Migration
  def change
    def up
      drop_table :stash_engine_identifier_states
    end
    def down
      raise ActiveRecord::IrreversibleMigration
    end
  end
end
