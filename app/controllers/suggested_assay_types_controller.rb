class SuggestedAssayTypesController < ApplicationController
  # all login users can edit their OWN created assay types
  # only admins can manage(i.e. edit and delete)

  before_filter :check_allowed_to_manage_types, :only => [:destroy, :manage]

  before_filter :project_membership_required_appended, :only => [:new_popup, :manage]

  before_filter :find_and_authorize_requested_item, :only => [:edit, :destroy]



  def set_is_modelling
     uri = params[:uri]
     is_modelling = ontology_hash_for_is_modelling[uri]
     render :update do |page|
       page['suggested_assay_type_is_for_modelling'].value = is_modelling
     end
  end
  def new_popup
    @suggested_assay_type = SuggestedAssayType.new
    @suggested_assay_type.is_for_modelling = string_to_boolean params[:is_for_modelling]
    @suggested_assay_type.link_from= params[:link_from]
    respond_to do |format|
      format.html { render :layout => false }
      format.xml { render :xml => @suggested_assay_type }
    end
  end



  def new
    @suggested_assay_type = SuggestedAssayType.new
    respond_to do |format|
      format.html
      format.xml { render :xml => @suggested_assay_type }
    end
  end

  def edit
    respond_to do |format|
      format.html
      format.js
      format.xml { render :xml => @suggested_assay_type }
    end
  end

  def create
    @suggested_assay_type = SuggestedAssayType.new(params[:suggested_assay_type])
    @suggested_assay_type.contributor_id= User.current_user.try(:person_id)
    saved = @suggested_assay_type.save
    if @suggested_assay_type.link_from == "assays"
      render :update do |page|
        if saved
          page.call "RedBox.close"
          page.replace_html 'assay_assay_types_list', :partial => "assays/assay_types_list", :locals => {:suggested_assay_type => @suggested_assay_type, :is_for_modelling => @suggested_assay_type.is_for_modelling}

        else
          page.alert("Fail to create new assay type. #{@suggested_assay_type.errors.full_messages}")
        end
      end
    else
      respond_to do |format|
        if saved
          flash[:notice] = "#{t('assays.assay')} type was successfully created."
          format.html { redirect_to(:action => "manage") }
          format.xml { head :ok }
        else
          format.html { render :action => :new }
          format.xml { render :xml => @suggested_assay_type.errors, :status => :unprocessable_entity }
        end
      end
    end


  end

  def update
    @suggested_assay_type=SuggestedAssayType.find(params[:id])
    @suggested_assay_type.attributes = params[:suggested_assay_type]
    saved = @suggested_assay_type.save
    if params[:commit_popup]
      render :update do |page|
        if saved
          page.replace_html 'assay_assay_types_list', :partial => "assays/assay_types_list", :locals => {:suggested_assay_type => @suggested_assay_type, :is_for_modelling => @suggested_assay_type.is_for_modelling}
          page.call "RedBox.close"
        else
          page.alert("Fail to edit assay type. #{@suggested_assay_type.errors.full_messages}")
        end
      end

    else
      respond_to do |format|
        if saved
          flash[:notice] = "#{t('assays.assay')} type was successfully updated."
          format.html { redirect_to(:action => "manage") }
          format.xml { head :ok }
        else
          format.html { render :action => :edit }
          format.xml { render :xml => @suggested_assay_type.errors, :status => :unprocessable_entity }
        end
      end
    end
  end

  def manage
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def destroy
    respond_to do |format|
      if @suggested_assay_type.can_destroy?
        title = @suggested_assay_type.label
        @suggested_assay_type.destroy
        flash[:notice] = "#{t('assays.assay')} type #{title} was deleted."
        format.html { redirect_to(:action => "manage") }
        format.xml { head :ok }
      else
        if !@suggested_assay_type.children.empty?
          flash[:error]="Unable to delete #{t('assays.assay').downcase} types with children"
        elsif !@suggested_assay_type.get_child_assays.empty?
          flash[:error]="Unable to delete #{t('assays.assay').downcase} type due to reliance from #{@suggested_assay_type.get_child_assays.count} existing #{t('assays.assay').downcase.pluralize} on child #{t('assays.assay').downcase} types"
        elsif !@suggested_assay_type.assays.empty?
          flash[:error]="Unable to delete #{t('assays.assay').downcase} type due to reliance from #{@suggested_assay_type.get_child_assays.count} existing #{t('assays.assay').downcase.pluralize}"
        end
        format.html { redirect_to(:action => "manage") }
        format.xml { render :xml => @suggested_assay_type.errors, :status => :unprocessable_entity }
      end
    end
  end


  private

  def string_to_boolean string
    if string=="true"
      return true
    elsif string == "false"
      return false
    else

    end
  end

  def ontology_hash_for_is_modelling
      @hash ||= build_is_modelling_hash
  end

  def build_is_modelling_hash
    result = {}
    Seek::Ontologies::AssayTypeReader.instance.class_hierarchy.hash_by_uri.each do |uri, clz|
      result[uri] = false
      clz.suggested_children.each do |child|
        result[child.uri] = false
        result.merge! build_suggested_children_hash(child, false)
      end
    end

    Seek::Ontologies::ModellingAnalysisTypeReader.instance.class_hierarchy.hash_by_uri.each do |uri, clz|
      result[uri] = true
      clz.suggested_children.each do |child|
        result[child.uri] = true
        result.merge! build_suggested_children_hash(child, true)
      end
    end

    result
  end

  def build_suggested_children_hash suggested_type, is_for_modelling
    result = {}
    suggested_type.children.each do |child|
        result[child.uri] = is_for_modelling
        result.merge!(build_suggested_children_hash child, is_for_modelling)
      end
    result
  end



end
