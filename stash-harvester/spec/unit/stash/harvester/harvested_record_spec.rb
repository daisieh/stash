require 'spec_helper'

module Stash
  module Harvester
    describe HarvestedRecord do

      before(@each) do
        @timestamp = Time.now.utc
        @record = HarvestedRecord.new(identifier: 'an identifier', timestamp: @timestamp)
      end

      describe '#initialize' do
        it 'sets the identifier' do
          expect(@record.identifier).to eq('an identifier')
        end

        it 'requires an identifier' do
          expect { HarvestedRecord.new(timestamp: @timestamp) }.to raise_error(ArgumentError)
        end

        it 'sets the timestamp' do
          expect(@record.timestamp).to eq(@timestamp)
        end

        it 'sets the deleted flag' do
          deleted_record = HarvestedRecord.new(identifier: 'an identifier', timestamp: @timestamp, deleted: true)
          expect(deleted_record.deleted?).to be(true)
        end

        it 'defaults to deleted=false' do
          expect(@record.deleted?).to be(false)
        end

        it 'requires a timestamp' do
          expect { HarvestedRecord.new(identifier: 'an identifier') }.to raise_error(ArgumentError)
        end

      end

      describe '#content' do
        it 'is abstract' do
          expect { @record.content }.to raise_error(NoMethodError)
        end
      end

      describe '#as_wrapper' do
        it 'parses the content' do
          def @record.content
            @content ||= File.read('spec/data/wrapped_datacite/wrapped-datacite-example.xml')
          end
          wrapper = @record.as_wrapper
          expect(wrapper).to be_a(Stash::Wrapper::StashWrapper)
          id = wrapper.identifier
          expect(id).to be_a(Stash::Wrapper::Identifier)
          expect(id.type).to eq(Stash::Wrapper::IdentifierType::DOI)
          expect(id.value).to eq('10.5072/example-full')
        end
      end
    end
  end
end
