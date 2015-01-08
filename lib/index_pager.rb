module IndexPager    
  include Seek::FacetedBrowsing

  def index
    controller = self.controller_name.downcase
    unless Seek::Config.faceted_browsing_enabled && Seek::Config.facet_enable_for_pages[controller] && ie_support_faceted_browsing?
      model_name=controller.classify
      model_class=eval(model_name)
      objects = eval("@"+controller)
      objects.size
      @hidden=0
      params[:page] ||= Seek::Config.default_page(controller)

      objects=model_class.paginate_after_fetch(objects, :page=>params[:page],
                                                        :latest_limit => Seek::Config.limit_latest
                                              ) unless objects.respond_to?("page_totals")
      eval("@"+controller+"= objects")
    end

    respond_to do |format|
      format.html
      format.xml
    end

  end

  def find_assets  action="view"
    controller = self.controller_name.downcase
    model_class=controller.classify.constantize
    if model_class.respond_to? :all_authorized_for
      found = model_class.all_authorized_for action, User.current_user
    else
      found = model_class.respond_to?(:default_order) ? model_class.default_order : model_class.all
    end
    found = apply_filters(found)
    
    eval("@" + controller + " = found")
  end

end