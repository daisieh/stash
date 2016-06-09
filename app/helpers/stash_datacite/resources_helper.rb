module StashDatacite
  module ResourcesHelper
    def citation(creators, title, resource_type, version, identifier, publication_years)
      publication_year = publication_years.try(:first).try(:publication_year) || Time.now.year
      title = title.try(:title)
      publisher = current_tenant.try(:long_name)
      resource_type = resource_type.try(:resource_type)
      ["#{creator_citation_format(creators)} (#{publication_year})", h(title), h(version), h(publisher), h(resource_type), target_url(identifier)].reject(&:blank?).join(", ").html_safe
    end

    def target_url(identifier)
      if identifier
        "#{link_to("https://dx.doi.org/#{identifier}", "https://dx.doi.org/#{identifier}", target: '_blank')} (opens in a new window)"
      else
        'https://dx.doi.org/placeholderDOI'
      end
    end

    def creator_citation_format(creators)
      return '' if creators.blank?
      str_creator = creators.map{|c| c.creator_full_name unless c.creator_full_name.match(/^[ ,]+$/) }.compact
      return '' if str_creator.blank?
      return "#{str_creator.first} et al." if str_creator.length > 4
      str_creator.join('; ')
    end
  end
end
