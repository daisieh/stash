# EventData is the DataCite API for getting stats about citations and usage.
# They currently do not have totals so we need to get large swaths of data and add it up on the client side instead
# of doing it a database where it is probably easier and more efficient.
module Stash
  module EventData
    Dir.glob(File.expand_path('event_data/*.rb', __dir__)).sort.each(&method(:require))

    def logger
      Rails.logger
    end

    # These methods are mixed in to citations and usage classes
    protected

    def generic_query(params:)
      hash = {
        'mailto'  =>  @email,
        'rows'    =>  10_000, # this one for crossref
      }
      response = make_reliable { RestClient.get @base_url, params: hash.merge(params) }
      JSON.parse(response.body)
    end

    def make_reliable
      retries = 5
      begin
        yield
      rescue RestClient::InternalServerError => ex
        raise ex if retries < 1
        retries -= 1
        sleep 0.6
        retry
      end
    end
  end
end
