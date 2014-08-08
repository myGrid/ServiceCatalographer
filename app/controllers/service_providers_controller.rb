# ServiceCatalographer: app/controllers/service_providers_controller.rb
#
# Copyright (c) 2008-2010, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details.

class ServiceProvidersController < ApplicationController
  
  before_filter :disable_action, :only => [ :new, :edit, :create ]
  before_filter :disable_action_for_api, :except => [ :index, :show, :annotations, :annotations_by, :services, :filters, :filtered_index ]
  
  skip_before_filter :verify_authenticity_token, :only => [ :auto_complete ]

  before_filter :parse_filtered_index_params, :only => :filtered_index

  before_filter :parse_current_filters, :only => [ :index, :filtered_index ]
  
  before_filter :get_filter_groups, :only => [ :filters ]

  before_filter :parse_sort_params, :only => [ :index, :filtered_index ]
  
  before_filter :find_service_providers, :only => [ :index, :filtered_index ]
  
  before_filter :find_service_provider, :only => [ :show, :edit, :update, :upload_logo, :remove_logo, :destroy, :annotations, :annotations_by,
                                                   :edit_by_popup, :profile, :services, :hostnames]
  
  before_filter :authorise, :only => [ :edit_by_popup, :update,  :destroy ]

  set_tab :profile, :service_providers, :only => [:profile, :show]
  set_tab :services, :service_providers, :only => [:services]
  set_tab :hostnames, :service_providers, :only => [:hostnames]
  before_filter :load_tab_variables, :only => [:profile, :services, :hostnames, :show]
  before_filter :show, :only => [:profile, :services, :hostnames]

  # GET /service_providers
  # GET /service_providers.xml
  def index
    respond_to do |format|
      format.html # index.html.erb
      format.xml  # index.xml.builder
      format.json { render :json => ServiceCatalographer::Api::Json.index("service_providers", json_api_params, @service_providers).to_json }
      format.bljson { render :json => ServiceCatalographer::Api::Bljson.index("service_providers", @service_providers).to_json }
    end
  end

  # POST /filtered_index
  # Example Input (differs based on available filters):
  #
  # { 
  #   :filters => { 
  #     :p => [ 67, 23 ], 
  #     :tag => [ "database" ], 
  #     :c => ["Austria", "south Africa"] 
  #   }
  # }
  def filtered_index
    index
  end

  # GET /service_providers/1
  # GET /service_providers/1.xml
  def show
    respond_to do |format|
      format.html { render 'service_providers/show.html.erb'}# show.html.erb
      format.xml  # show.xml.builder
      format.json { render :json => @service_provider.to_json }
    end
  end
  def load_tab_variables
  @provider_hostnames = @service_provider.service_provider_hostnames

  unless is_api_request?
    @provider_services = @service_provider.services.paginate(:page => params[:page],
                                                             :order => "created_at DESC")
  end
  end

  def profile ; end
  def services ; end
  def hostnames ; end

  def annotations
    respond_to do |format|
      format.html { disable_action }
      format.xml { redirect_to(generate_include_filter_url(:asp, @service_provider.id, "annotations", :xml)) }
      format.json { redirect_to(generate_include_filter_url(:asp, @service_provider.id, "annotations", :json)) }
    end
  end
  
  def annotations_by
    respond_to do |format|
      format.html { disable_action }
      format.xml { redirect_to(generate_include_filter_url(:sosp, @service_provider.id, "annotations", :xml)) }
      format.json { redirect_to(generate_include_filter_url(:sosp, @service_provider.id, "annotations", :json)) }
    end
  end
  
  def services
    respond_to do |format|
      format.html { disable_action }
      format.xml { redirect_to(generate_include_filter_url(:p, params[:id], "services", :xml)) }
      format.json { redirect_to(generate_include_filter_url(:p, params[:id], "services", :json)) }
    end
  end

  def edit_by_popup
    respond_to do |format|
      format.js { render :layout => false }
    end
  end

  def upload_logo
    @service_provider.logo = params[:service_provider][:logo]
    success = @service_provider.save!

    if success
      respond_to do |format|
        flash[:notice] = "Successfully added #{@service_provider.logo.original_filename}"
        format.html { redirect_to @service_provider }
        format.xml  { head :ok }
      end
    else # failure
      respond_to do |format|
        flash[:notice] = "Failed to add #{@service_provider.logo.original_filename}"
        format.html { redirect_to @service_provider }
        format.xml  { render :xml => '', :status => 406 }
      end
    end # if success
  end

  def remove_logo
    @service_provider.logo = nil
    @service_provider.save!
    respond_to do |format|
      format.html { redirect_to @service_provider }
      format.xml  { render :xml => '', :status => 406 }
    end

  end

  def update
    name = params[:name] || ""
    name.chomp!
    name.strip!
    
    not_changed = name.downcase == @service_provider.name.downcase
    
    success = true
    
    if name.blank? || not_changed # complain
      flash[:error] = (not_changed ? "The new name cannot be the same as the old one" : "Please provide a valid provider name")
      success = false
    else # do MERGE OR RENAME
      existing_provider = ServiceProvider.find_by_name(name)
      current_sp_name = @service_provider.name
      
      if existing_provider.nil? # do RENAME
        @service_provider.name = name
        @service_provider.save!
      
        flash[:notice] = "The Service Provider's name has been updated"
      elsif @service_provider.merge_into(existing_provider) # do MERGE
        flash[:notice] = "Service Provider '#{current_sp_name}' was successfully merged into '#{existing_provider.name}'"
        @service_provider = existing_provider
      else # complain
        flash[:error] = "An error occured while merging this Service Provider into #{existing_provider.name}.<br/>" +
                        "Please contact us if this error persists."
        success = false
      end
      
    end # if name.blank? || not_changed
    
    if success
      respond_to do |format|
        format.html { redirect_to @service_provider }
        format.xml  { head :ok }
      end      
    else # failure
      respond_to do |format|
        format.html { redirect_to @service_provider }
        format.xml  { render :xml => '', :status => 406 }
      end
    end # if success
  end

  def auto_complete
    @name_fragment = params[:name] || ''

    # Old Rails 2 style
    #@results = ServiceProvider.all(
    #                                :conditions => "name like '%" + @name_fragment.downcase + "%'")
    @results = ServiceProvider.where("name like '%" + @name_fragment.downcase + "%'")

    render :inline => "<%= auto_complete_result @results, 'name', @name_fragment %>", :layout => false
  end

  def filters
    respond_to do |format|
      format.html { disable_action }
      format.xml # filters.xml.builder
      format.json { render :json => ServiceCatalographer::Api::Json.filter_groups(@filter_groups).to_json }
    end
  end
  
  def destroy
    respond_to do |format|
      if @service_provider.destroy
        flash[:notice] = "Service provider '#{@service_provider.name}' has been deleted"
        format.html { redirect_to root_url }
        format.xml  { head :ok }
      else
        flash[:error] = "Failed to delete service provider '#{@service_provider.name}'"
        format.html { redirect_to service_provider_url(@service_provider) }
      end
    end
  end

protected
  
  def parse_sort_params
    sort_by_allowed = [ "created", "name" ]
    @sort_by = if params[:sort_by] && sort_by_allowed.include?(params[:sort_by].downcase)
      params[:sort_by].downcase
    else
      "name"
    end
    
    sort_order_allowed = [ "asc", "desc" ]
    @sort_order = if params[:sort_order] && sort_order_allowed.include?(params[:sort_order].downcase)
      params[:sort_order].downcase
    else
      "asc"
    end
  end
  
  def find_service_providers
    
    # Sorting
    
    order = 'service_providers.created_at DESC'
    order_field = nil
    order_direction = nil
    
    case @sort_by
      when 'created'
        order_field = "created_at"
      when 'name'
        order_field = "name"
    end
    
    case @sort_order
      when 'asc'
        order_direction = 'ASC'
      when 'desc'
        order_direction = "DESC"
    end
    
    unless order_field.blank? or order_direction.nil?
      order = "service_providers.#{order_field} #{order_direction}"
    end
    
    conditions, joins = ServiceCatalographer::Filtering::ServiceProviders.generate_conditions_and_joins_from_filters(@current_filters, params[:q])
    
    if self.request.format == :bljson
      finder_options = {
        :select => "service_providers.id, service_providers.name",
        :order => order,
        :conditions => conditions,
        :joins => joins
      }
      
      @service_providers = ActiveRecord::Base.connection.select_all(ServiceProvider.send(:construct_finder_arel, finder_options))
    else
      @service_providers = ServiceProvider.paginate(:page => @page,
                                                    :per_page => @per_page,
                                                    :order => order,
                                                    :conditions => conditions,
                                                    :joins => joins)
    end
  end
  
  def find_service_provider
    @service_provider = ServiceProvider.find(params[:id])
  end
  
  def authorise
    unless ServiceCatalographer::Auth.allow_user_to_curate_thing?(current_user, @service_provider)
      error_to_back_or_home("You are not allowed to perform this action")
      return false
    end
    
    # Additionally, for the destroy action check that the service provider has no services
    if action_name == "destroy" && @service_provider.services.count != 0
      error_to_back_or_home("Cannot delete a service provider that has some services registered")
      return false
    end
    
    return true
  end

end
