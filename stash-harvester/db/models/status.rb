module Stash
  module Harvester
    module Models
      # TODO: Merge with Indexer::IndexStatus?
      module Status
        ALL = %i[pending in_progress completed failed].freeze

        PENDING = ALL.index(:pending)
        IN_PROGRESS = ALL.index(:in_progress)
        COMPLETED = ALL.index(:completed)
        FAILED = ALL.index(:failed)
      end
    end
  end
end
