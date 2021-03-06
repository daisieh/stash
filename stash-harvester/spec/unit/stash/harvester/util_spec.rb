require 'spec_helper'

module Stash
  module Harvester
    describe Util do
      describe '#to_uri' do
        it 'returns nil for nil' do
          expect(Util.to_uri(nil)).to be_nil
        end

        it 'return a URI unchanged' do
          uri = URI('http://example.org')
          expect(Util.to_uri(uri)).to be(uri)
        end

        it 'converts a string to a URI' do
          url = 'http://example.org/'
          expect(Util.to_uri(url)).to eq(URI(url))
        end

        it 'strips whitespace before converting strings' do
          url = 'http://example.org/'
          expect(Util.to_uri(" #{url} ")).to eq(URI(url))
        end

        it 'fails on bad URLs' do
          invalid_url = 'I am not a valid URL'
          expect { Util.to_uri(invalid_url) }.to raise_error(URI::InvalidURIError)
        end
      end

      describe '#utc_or_nil' do
        it 'returns a valid UTC Time parameter unchanged' do
          time = Time.now.utc
          expect(Util.utc_or_nil(time)).to be(time)
        end
        it 'raises ArgumentError for a Time that is not UTC' do
          time = Time.new(2002, 10, 31, 2, 2, 2, '+02:00')
          expect { Util.utc_or_nil(time) }.to raise_error do |e|
            expect(e).to be_an ArgumentError
            expect(e.message).to include(time.to_s)
          end
        end
      end

    end
  end
end
