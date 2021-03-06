require 'spec_helper'
require 'stash/harvest_and_index_job'
require 'rest-client'
require 'webmock/rspec'

module Stash
  describe HarvestAndIndexJob do

    # ##############################
    # Fixture
    # ##############################

    attr_reader :harvest_job_id
    attr_reader :index_job_id
    attr_reader :from_time
    attr_reader :until_time

    attr_reader :persistence_mgr
    attr_reader :solr
    attr_reader :wrappers
    attr_reader :arks
    attr_reader :dois
    attr_reader :job

    def source_config
      @config.source_config
    end

    def index_config
      @config.index_config
    end

    def metadata_mapper
      @config.metadata_mapper
    end

    def timestamp(i)
      wrappers[i].version_date.to_time
    end

    def record_count
      wrappers.size
    end

    def harvest_task
      job.harvest_task
    end

    def query_url
      harvest_task.query_uri
    end

    before(:all) do
      WebMock.disable_net_connect!
    end

    before(:each) do
      # Mock persistence
      persistence_config = instance_double(PersistenceConfig)
      allow(PersistenceConfig).to receive(:new) { persistence_config }

      @persistence_mgr = instance_double(PersistenceManager).as_null_object
      allow(persistence_config).to receive(:create_manager) { @persistence_mgr }

      @harvest_job_id = 17
      allow(@persistence_mgr).to receive(:begin_harvest_job).with(any_args).and_return(@harvest_job_id)

      @index_job_id = 19
      allow(@persistence_mgr).to receive(:begin_index_job).with(any_args).and_return(@index_job_id)

      # Mock OAI
      @wrappers = []
      @arks = []
      @dois = []
      oai_records = %w[
        spec/data/wrapped_datacite/wrapped-datacite-all-geodata.xml
        spec/data/wrapped_datacite/wrapped-datacite-no-geodata.xml
        spec/data/wrapped_datacite/wrapped-datacite-place-only.xml
      ].map do |xml|
        stash_wrapper = Stash::Wrapper::StashWrapper.parse_xml(File.read(xml))
        @wrappers << stash_wrapper
        id_value = stash_wrapper.id_value
        ark = "http://n2t.net/ark:/#{Digest::MD5.hexdigest(id_value)}"
        @arks << ark
        doi = "doi:#{id_value}"
        @dois << doi
        datestamp = stash_wrapper.version_date.to_time.utc.xmlschema

        record = REXML::Document.new(['<record>',
                                      '  <header> ',
                                      "   <identifier>#{ark}</identifier>",
                                      "   <datestamp>#{datestamp}</datestamp>",
                                      '  </header> ',
                                      '</record>'].join("\n")).root

        metadata = REXML::Element.new('metadata')
        metadata.add_element(stash_wrapper.save_to_xml)
        record.add_element(metadata)
        ::OAI::Record.new(record)
      end
      list_records_response = instance_double(::OAI::ListRecordsResponse)
      allow(list_records_response).to receive(:full).and_return(oai_records)

      allow_any_instance_of(::OAI::Client).to receive(:list_records).with(any_args).and_return(list_records_response)

      allow(@persistence_mgr).to receive(:record_harvested_record).and_return(*(0...oai_records.length).to_a)

      # Mock Solr
      @solr = instance_double(RSolr::Client)
      allow(@solr).to receive(:add)
      allow(@solr).to receive(:commit)
      allow(RSolr::Client).to receive(:new) do |_connection, options|
        @rsolr_options = options
        @solr
      end

      # Config
      @config = Config.from_file('spec/data/stash-harvester.yml')

      @from_time = Time.utc(1914, 8, 4, 23)
      @until_time = Time.utc(2018, 11, 11, 10)
      @job = HarvestAndIndexJob.new(
        update_uri: nil,
        source_config: source_config,
        index_config: index_config,
        metadata_mapper: metadata_mapper,
        persistence_manager: @persistence_mgr,
        from_time: from_time,
        until_time: until_time
      )
    end

    after(:each) do
      allow(RSolr::Client).to receive(:new).and_call_original
      allow_any_instance_of(::OAI::Client).to receive(:list_records).and_call_original
      allow(PersistenceConfig).to receive(:new).with(any_args).and_call_original
    end

    # ##############################
    # Specs
    # ##############################

    describe '#initialize' do

      it 'creates a harvest task' do
        harvest_task = job.harvest_task
        expect(harvest_task).to be_a(Harvester::OAI::OAIHarvestTask)
        expect(harvest_task.config).to be(source_config)
        expect(harvest_task.from_time).to be(from_time)
        expect(harvest_task.until_time).to be(until_time)
      end

      it 'creates an indexer' do
        indexer = job.indexer
        expect(indexer).to be_a(Indexer::Solr::SolrIndexer)
        expect(indexer.config).to be(index_config)
        expect(indexer.metadata_mapper).to be(metadata_mapper)
      end
    end

    describe '#harvest_and_index' do
      it 'harvests and indexes records (even if no block given)' do
        expect(@solr).to receive(:add).exactly(@wrappers.length).times
        job.harvest_and_index
      end

      it 'yields the submission time and status (completed/failed) for each record' do
        now = Time.now.utc.to_i
        i = 0
        job.harvest_and_index do |result|
          expect(result).to be_an(Indexer::IndexResult)
          expect(result.status).to eq(Indexer::IndexStatus::COMPLETED)
          expect(result.errors).to eq([])
          expect(result.timestamp.to_i).to be_within(3).of(now)
          harvested_record = result.record
          expect(harvested_record).to be_a(Harvester::HarvestedRecord)
          expect(harvested_record.identifier).to eq(arks[i])
          expect(harvested_record.timestamp).to eq(timestamp(i))
          expect(harvested_record.deleted?).to eq(false)
          i += 1
        end
        expect(i).to eq(record_count)
      end

      describe 'persistence' do

        it 'begins/ends a harvest job' do
          expect(persistence_mgr).to receive(:begin_harvest_job)
            .with(from_time: from_time, until_time: until_time, query_url: query_url)
            .and_return(harvest_job_id)
          expect(persistence_mgr).to receive(:end_harvest_job).with(harvest_job_id: harvest_job_id, status: Indexer::IndexStatus::COMPLETED)
          job.harvest_and_index
        end

        it 'begins/ends an index job' do
          expect(persistence_mgr).to receive(:begin_index_job).with(harvest_job_id: harvest_job_id, solr_url: index_config.uri) { index_job_id }
          expect(persistence_mgr).to receive(:end_index_job).with(index_job_id: index_job_id, status: Indexer::IndexStatus::COMPLETED)
          job.harvest_and_index
        end

        it 'sets the harvest status to failed in event of a pre-indexing failure' do
          e = Exception.new('(mock :harvest_records error)')
          expect(harvest_task).to receive(:harvest_records).and_raise(e)
          expect(persistence_mgr).to receive(:end_harvest_job).with(harvest_job_id: harvest_job_id, status: Indexer::IndexStatus::FAILED)
          expect { job.harvest_and_index }.to raise_error(e)
        end

        it 'sets the index status to failed in event of an indexing failure' do
          e = Exception.new('(mock :add error)')
          expect(solr).to receive(:add).and_raise(e)
          expect(persistence_mgr).to receive(:end_index_job).with(index_job_id: index_job_id, status: Indexer::IndexStatus::FAILED)
          expect { job.harvest_and_index }.to raise_error(e)
        end

        it 'sets the harvest status to failed in event of an indexing failure' do
          e = Exception.new('(mock :add error)')
          expect(solr).to receive(:add).and_raise(e)
          expect(persistence_mgr).to receive(:end_harvest_job).with(harvest_job_id: harvest_job_id, status: Indexer::IndexStatus::COMPLETED)
          expect { job.harvest_and_index }.to raise_error(e)
        end

        it 'creates harvested_ and indexed_records' do
          (0...record_count).each do |i|
            expect(persistence_mgr).to receive(:record_harvested_record).with(
              harvest_job_id: harvest_job_id,
              identifier: arks[i],
              timestamp: timestamp(i),
              deleted: false
            ) { i }
            expect(persistence_mgr).to receive(:record_indexed_record).with(
              index_job_id: index_job_id,
              harvested_record_id: i,
              status: Indexer::IndexStatus::COMPLETED
            )
            job.harvest_and_index
          end
        end
      end

      describe 'logging' do
        attr_reader :out

        def logged
          out.string
        end

        before(:each) do
          @out = StringIO.new
          Harvester.log_device = out
        end

        after(:each) do
          Harvester.log_device = $stdout
        end

        it 'logs the from_time and until_time'

        it 'logs each successfully harvested record' do
          job.harvest_and_index
          expect(logged).to include(harvest_job_id.to_s)
          (0...record_count).each do |i|
            expect(logged).to include(arks[i])
            expect(logged).to include(timestamp(i).utc.xmlschema)
            expect(logged).to include(false.to_s)
          end
        end

        it 'logs each successfully indexed record' do
          job.harvest_and_index
          expect(logged).to include(index_job_id.to_s)
          (0...record_count).each do |i|
            expect(logged).to include(arks[i])
            expect(logged).to include(timestamp(i).utc.xmlschema)
            expect(logged).to include(Indexer::IndexStatus::COMPLETED.value.to_s)
          end
        end

        it 'logs each successfully deleted record'
        it 'logs each failed record'

        it 'logs index job failures' do
          e = Exception.new('(mock :add error)')
          expect(solr).to receive(:add).and_raise(e)
          expect { job.harvest_and_index }.to raise_error(e)
          expect(logged).to include(index_job_id.to_s)
          expect(logged).to include(Indexer::IndexStatus::FAILED.value.to_s)
        end

        it 'logs harvest job failures' do
          e = Exception.new('(mock :list_records error)')
          allow_any_instance_of(::OAI::Client).to receive(:list_records).and_raise(e)
          expect { job.harvest_and_index }.to raise_error(e)
          expect(logged).to include(harvest_job_id.to_s)
          expect(logged).to include(Indexer::IndexStatus::FAILED.value.to_s)
        end

        it 'logs :post_update failures' do
          update_uri_base = 'http://stash-test.example.org/stash/datasets/'
          job = HarvestAndIndexJob.new(
            update_uri: URI(update_uri_base),
            source_config: source_config,
            index_config: index_config,
            metadata_mapper: metadata_mapper,
            persistence_manager: @persistence_mgr,
            from_time: from_time,
            until_time: until_time
          )

          stubs = []
          expected_uris = []
          dois.each_with_index do |doi, i|
            ark = arks[i]
            expected_uri = "#{update_uri_base}/#{doi}"
            expected_payload = { 'record_identifier' => ark }.to_json
            stubs << stub_request(:patch, expected_uri)
              .with(body: expected_payload)
              .to_timeout
            expected_uris << expected_uri
          end

          job.harvest_and_index

          expected_uris.each_with_index do |uri, i|
            expect(logged).to include(uri)
            expect(logged).to include(arks[i])
            expect(logged.downcase).to include('timed out')
          end
        end
      end

      describe '#post_update' do
        it 'posts an update for each record, if an update URI is configured' do
          update_uri_base = 'http://stash-test.example.org/stash/datasets/'
          job = HarvestAndIndexJob.new(
            update_uri: URI(update_uri_base),
            source_config: source_config,
            index_config: index_config,
            metadata_mapper: metadata_mapper,
            persistence_manager: @persistence_mgr,
            from_time: from_time,
            until_time: until_time
          )

          stubs = []
          dois.each_with_index do |doi, i|
            ark = arks[i]
            expected_uri = "#{update_uri_base}/#{doi}"
            expected_payload = { 'record_identifier' => ark }.to_json
            stubs << stub_request(:patch, expected_uri).with(body: expected_payload)
          end

          job.harvest_and_index

          aggregate_failures('updates') do
            stubs.each { |stub| expect(stub).to have_been_requested }
          end
        end
      end
    end

  end
end
