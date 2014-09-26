require 'seek/external_search'

module SearchHelper
  include Seek::ExternalSearch
  def search_type_options
    search_type_options = ["all"] | Seek::Util.searchable_types.collect{|c|  c.name.underscore.pluralize }
    return search_type_options
  end
    
  def saved_search_image_tag saved_search
    tiny_image = image_tag "famfamfam_silk/find.png", :style => "padding: 11px; border:1px solid #CCBB99;background-color:#FFFFFF;"
    return link_to_draggable(tiny_image, saved_search_path(saved_search.id), :title=>tooltip_title_attrib("Search: #{saved_search.search_query} (#{saved_search.search_type})"),:class=>"saved_search", :id=>"sav_#{saved_search.id}")
  end

  def force_search_type search_type_options
    search_type_options.each do |type|
      if current_page?("/"+type[1].to_s)
        @search_type=type[1].to_s
      end
    end
  end

  def external_search_tooltip_text

    text = "Checking this box allows external resources to be includes in the search.<br/>"
    text << "External resources include: "
    text << search_adaptor_names.collect{|name| "<b>#{name}</b>"}.join(",")
    text << "<br/>"
    text << "This means the search will take longer, but will include results from other sites"
    text.html_safe
  end
  def get_resource_hash scale, external_resource_hash
    internal_resource_hash = {}
    if external_resource_hash.blank?
      @results_scaled[scale].each do |item|
        tab = item.respond_to?(:tab) ? item.tab : item.class.name
        if item.respond_to?(:is_external_search_result?) && item.is_external_search_result?
          external_resource_hash[tab] = [] unless external_resource_hash[tab]
          external_resource_hash[tab] << item
        else
          internal_resource_hash[tab] = [] unless internal_resource_hash[tab]
          internal_resource_hash[tab] << item
        end
      end
    else
      @results_scaled[scale].each do |item|
        tab = item.respond_to?(:tab) ? item.tab : item.class.name
        unless item.respond_to?(:is_external_search_result?) && item.is_external_search_result?
          internal_resource_hash[tab] = [] unless internal_resource_hash[tab]
          internal_resource_hash[tab] << item
        end
      end
    end
    [internal_resource_hash, external_resource_hash]
  end

  def options_for_field_set(container, selected = nil)
         return container if String === container

         selected, disabled = extract_selected_and_disabled(selected).map do | r |
            Array.wrap(r).map { |item| item.to_s }
         end

         container.map do |element|
           html_attributes = option_html_attributes(element)
           text, value = option_text_and_value(element).map { |item| item.to_s }
           selected_attribute = ' selected="selected"' if option_value_selected?(value, selected)
           disabled_attribute = ' disabled="disabled"' if disabled && option_value_selected?(value, disabled)
           %(<option value="#{ERB::Util.html_escape(value)}"#{selected_attribute}#{disabled_attribute}#{html_attributes}>#{ERB::Util.html_escape(text)}</option>)
         end.join("\n").html_safe

  end

end
