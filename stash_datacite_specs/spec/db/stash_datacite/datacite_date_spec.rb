require 'db_spec_helper'

module StashDatacite
  describe DataciteDate do
    attr_reader :resource
    before(:each) do
      user = StashEngine::User.create(
        uid: 'lmuckenhaupt-example@example.edu',
        email: 'lmuckenhaupt@example.edu',
        tenant_id: 'dataone'
      )
      @resource = StashEngine::Resource.create(user_id: user.id)
    end

    describe 'date_type_mapping_obj' do
      it 'returns nil for nil' do
        expect(DataciteDate.date_type_mapping_obj(nil)).to be_nil
      end
      it 'maps type values to enum instances' do
        Datacite::Mapping::DateType.each do |type|
          value_str = type.value
          expect(DataciteDate.date_type_mapping_obj(value_str)).to be(type)
        end
      end
      it 'returns the enum instance for a model object' do
        DataciteDate::DateTypesStrToFull.keys.each do |date_type|
          date = DataciteDate.create(
            resource_id: resource.id,
            date: 'Conscriptio super monstruosum vitulum extraneissimum',
            date_type: date_type
          )
          date_type_friendly = date.date_type_friendly
          enum_instance = Datacite::Mapping::DateType.find_by_value(date_type_friendly)
          expect(date.date_type_mapping_obj).to be(enum_instance)
        end
      end
    end

  end
end
