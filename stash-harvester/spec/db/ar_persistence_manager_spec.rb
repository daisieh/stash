require 'db_spec_helper'
require 'ar_persistence_manager'

module Stash
  include Stash::Harvester::Models

  describe ARPersistenceManager do
    before(:each) do
      @mgr = ARPersistenceManager.new
    end

    describe '#begin_harvest_job' do
      it 'creates a job' do
        from_time = Time.utc(2015, 1, 1)
        until_time = Time.utc(2016, 1, 1)
        query_url = URI('http://example.org/oai')

        now = Time.now.utc.to_i
        job_id = @mgr.begin_harvest_job(from_time: from_time, until_time: until_time, query_url: query_url)

        job = HarvestJob.first
        expect(job.id).to eq(job_id)
        expect(job.from_time).to eq(from_time)
        expect(job.until_time).to eq(until_time)
        expect(job.query_url).to eq(query_url.to_s)
        expect(job.start_time.to_i).to be_within(1).of(now)
        expect(job.end_time).to be_nil
        expect(job.in_progress?).to eq(true)
      end

      it 'defaults from_time and until_time to nil' do
        query_url = URI('http://example.org/oai')

        @mgr.begin_harvest_job(query_url: query_url)

        job = HarvestJob.first
        expect(job.from_time).to be_nil
        expect(job.until_time).to be_nil
      end
    end

    describe '#record_harvested_record' do
      it 'writes a record' do
        job_id = @mgr.begin_harvest_job(query_url: URI('http://example.org/oai'))
        identifier = 'doi:10.123/456'
        timestamp = Time.utc(1972, 5, 18)
        record_id = @mgr.record_harvested_record(
          harvest_job_id: job_id,
          identifier: identifier,
          timestamp: timestamp,
          deleted: true
        )
        record = HarvestedRecord.first
        expect(record.id).to eq(record_id)
        expect(record.harvest_job_id).to eq(job_id)
        expect(record.identifier).to eq(identifier)
        expect(record.timestamp).to eq(timestamp)
        expect(record.deleted?).to eq(true)
      end

      it 'defaults deleted to false' do
        job_id = @mgr.begin_harvest_job(query_url: URI('http://example.org/oai'))
        @mgr.record_harvested_record(
          harvest_job_id: job_id,
          identifier: 'doi:10.123/456',
          timestamp: Time.utc(1972, 5, 18)
        )
        record = HarvestedRecord.first
        expect(record.deleted?).to eq(false)
      end
    end

    describe '#end_harvest_job' do
      it 'updates the job record' do
        job_id = @mgr.begin_harvest_job(query_url: URI('http://example.org/oai'))
        now = Time.now.utc.to_i
        @mgr.end_harvest_job(
          harvest_job_id: job_id,
          status: Indexer::IndexStatus::COMPLETED
        )
        job = HarvestJob.first
        expect(job.in_progress?).to eq(false)
        expect(job.completed?).to eq(true)
        expect(job.end_time.to_i).to be_within(1).of(now)
      end

      it 'rejects an invalid status' do
        job_id = @mgr.begin_harvest_job(query_url: URI('http://example.org/oai'))
        expect do
          @mgr.end_harvest_job(
            harvest_job_id: job_id,
            status: 'elvis'
          )
        end.to raise_error(ArgumentError)
        job = HarvestJob.first
        expect(job.in_progress?).to eq(true)
      end
    end

    describe '#begin_index_job' do
      it 'creates a job' do
        harvest_job_id = @mgr.begin_harvest_job(query_url: URI('http://example.org/oai'))
        solr_url = URI('http://example.org/solr')
        now = Time.now.utc.to_i
        index_job_id = @mgr.begin_index_job(
          harvest_job_id: harvest_job_id,
          solr_url: solr_url
        )
        index_job = IndexJob.first
        expect(index_job.id).to eq(index_job_id)
        expect(index_job.harvest_job_id).to eq(harvest_job_id)
        expect(index_job.start_time.to_i).to be_within(1).of(now)
        expect(index_job.end_time).to be_nil
        expect(index_job.in_progress?).to eq(true)
      end
    end

    describe '#record_indexed_record' do
      it 'creates a record' do
        harvest_job_id = @mgr.begin_harvest_job(query_url: URI('http://example.org/oai'))
        harvested_record_id = @mgr.record_harvested_record(
          harvest_job_id: harvest_job_id,
          identifier: 'doi:10.123/456',
          timestamp: Time.utc(1972, 5, 18)
        )

        index_job_id = @mgr.begin_index_job(
          harvest_job_id: harvest_job_id,
          solr_url: URI('http://example.org/solr')
        )

        now = Time.now.utc.to_i
        @mgr.record_indexed_record(
          index_job_id: index_job_id,
          harvested_record_id: harvested_record_id,
          status: Indexer::IndexStatus::FAILED
        )

        indexed_record = IndexedRecord.first
        expect(indexed_record.index_job_id).to eq(index_job_id)
        expect(indexed_record.harvested_record_id).to eq(harvested_record_id)
        expect(indexed_record.submitted_time.to_i).to be_within(1).of(now)
        expect(indexed_record.failed?).to eq(true)
      end

      it 'rejects an invalid status' do
        harvest_job_id = @mgr.begin_harvest_job(query_url: URI('http://example.org/oai'))
        harvested_record_id = @mgr.record_harvested_record(
          harvest_job_id: harvest_job_id,
          identifier: 'doi:10.123/456',
          timestamp: Time.utc(1972, 5, 18)
        )
        index_job_id = @mgr.begin_index_job(
          harvest_job_id: harvest_job_id,
          solr_url: URI('http://example.org/solr')
        )
        expect do
          @mgr.record_indexed_record(
            index_job_id: index_job_id,
            harvested_record_id: harvested_record_id,
            status: 'elvis'
          )
        end.to raise_error(ArgumentError)
        expect(IndexedRecord.first).to be_nil
      end
    end

    describe '#end_index_job' do
      it 'updates the job record' do
        harvest_job_id = @mgr.begin_harvest_job(query_url: URI('http://example.org/oai'))
        index_job_id = @mgr.begin_index_job(
          harvest_job_id: harvest_job_id,
          solr_url: URI('http://example.org/solr')
        )
        now = Time.now.utc.to_i
        @mgr.end_index_job(index_job_id: index_job_id, status: Indexer::IndexStatus::COMPLETED)
        index_job = IndexJob.first
        expect(index_job.end_time.to_i).to be_within(1).of(now)
        expect(index_job.completed?).to eq(true)
      end

      it 'rejects an invalid status' do
        harvest_job_id = @mgr.begin_harvest_job(query_url: URI('http://example.org/oai'))
        index_job_id = @mgr.begin_index_job(
          harvest_job_id: harvest_job_id,
          solr_url: URI('http://example.org/solr')
        )
        expect do
          @mgr.end_index_job(
            index_job_id: index_job_id,
            status: 'elvis'
          )
        end.to raise_error(ArgumentError)
        job = IndexJob.first
        expect(job.in_progress?).to eq(true)
      end
    end

    describe 'scheduling' do

      before(:each) do
        @record_count = 3

        @harvest_job_completed = create(:indexed_harvest_job, record_count: @record_count, from_time: nil, start_time: Time.utc(2015, 7, 1))
        @harvested_records_completed = @harvest_job_completed.harvested_records

        @harvest_job_failed = create(
          :indexed_harvest_job,
          record_count: @record_count + 1,
          from_time: Time.utc(2015, 7, 1, 10),
          start_time: Time.utc(2015, 8, 1),
          index_record_status: :failed
        )
        @harvested_records_failed = @harvest_job_failed.harvested_records
      end

      describe 'find_newest_indexed_timestamp' do
        it 'returns the timestamp of the newest indexed record' do
          newest_indexed = HarvestedRecord.find_newest_indexed
          expected_timestamp = newest_indexed.timestamp

          newest_indexed_timestamp = @mgr.find_newest_indexed_timestamp
          expect(newest_indexed_timestamp).to be_a(Time)
          expect(newest_indexed_timestamp).to eq(expected_timestamp)
        end

        it 'returns nil if there are no indexed records' do
          @harvested_records_completed.each(&:destroy)
          expect(@mgr.find_newest_indexed_timestamp).to be_nil
        end
      end

      describe 'find_oldest_failed_timestamp' do
        it 'returns the timestamp of the oldest failed record' do
          oldest_failed = HarvestedRecord.find_oldest_failed
          expected_timestamp = oldest_failed.timestamp

          oldest_failed_timestamp = @mgr.find_oldest_failed_timestamp
          expect(oldest_failed_timestamp).to be_a(Time)
          expect(oldest_failed_timestamp).to eq(expected_timestamp)
        end

        it 'returns nil if there are no failed records' do
          @harvested_records_failed.each(&:destroy)
          expect(@mgr.find_oldest_failed_timestamp).to be_nil
        end
      end
    end

  end
end
