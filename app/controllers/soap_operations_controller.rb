# ServiceCatalographer: app/controllers/soap_operations_controller.rb
#
# Copyright (c) 2010, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details.


class SoapOperationsController < ApplicationController
  
  before_filter :disable_action, :only => [ :new, :create, :edit, :update, :destroy ]
  before_filter :disable_action_for_api, :except => [ :index, :filtered_index, :show, :annotations, :filters, :inputs, :outputs ]
  
  before_filter :parse_filtered_index_params, :only => :filtered_index

  before_filter :parse_current_filters, :only => [ :index, :filtered_index ]
  
  before_filter :get_filter_groups, :only => [ :filters ]
  
  before_filter :parse_sort_params, :only => [ :index, :filtered_index ]
  
  before_filter :find_soap_operations, :only => [ :index, :filtered_index ]
  
  before_filter :find_soap_operation, :only => [ :show, :annotations, :inputs, :outputs ]
  
  def index
    respond_to do |format|
      format.html { disable_action }
      format.xml # index.xml.builder
      format.json { render :json => ServiceCatalographer::Api::Json.index("soap_operations", json_api_params, @soap_operations).to_json }
      format.bljson { render :json => ServiceCatalographer::Api::Bljson.index("soap_operations", @soap_operations).to_json }
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
  
  def show
    @soap_service = @soap_operation.soap_service
    
    respond_to do |format|
      format.html # show.html.erb
      format.xml  # show.xml.builder
      format.json { render :json => @soap_operation.to_json }
    end
  end

  def inputs 
    respond_to do |format|
      format.html { disable_action }
      format.xml  # inputs.xml.builder
      format.json { render :json => @soap_operation.to_custom_json("inputs") }
    end
  end

  def outputs 
    respond_to do |format|
      format.html { disable_action }
      format.xml  # outputs.xml.builder
      format.json { render :json => @soap_operation.to_custom_json("outputs") }
    end
  end
  
  def annotations
    respond_to do |format|
      format.html { disable_action }
      format.xml { redirect_to(generate_filter_url(get_new_params_with_also_filter, "annotations", :xml)) }
      format.json { redirect_to(generate_filter_url(get_new_params_with_also_filter, "annotations", :json)) }
    end
  end
  
  def filters
    respond_to do |format|
      format.html { disable_action }
      format.xml # filters.xml.builder
      format.json { render :json => ServiceCatalographer::Api::Json.filter_groups(@filter_groups).to_json }
    end
  end

protected
  
  def parse_sort_params
    sort_by_allowed = [ "created", "name" ]
    @sort_by = if params[:sort_by] && sort_by_allowed.include?(params[:sort_by].downcase)
      params[:sort_by].downcase
    else
      "created"
    end
    
    sort_order_allowed = [ "asc", "desc" ]
    @sort_order = if params[:sort_order] && sort_order_allowed.include?(params[:sort_order].downcase)
      params[:sort_order].downcase
    else
      "desc"
    end
  end
  
  def find_soap_operations
    
    # Sorting
    
    order = 'soap_operations.created_at DESC'
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
      order = "soap_operations.#{order_field} #{order_direction}"
    end
    
    # Filtering
    
    conditions, joins = ServiceCatalographer::Filtering::SoapOperations.generate_conditions_and_joins_from_filters(@current_filters, params[:q])

    if self.request.format == :bljson
      
      finder_options = {
        :select => "soap_operations.id, soap_operations.name, soap_operations.archived_at",
        :order => order,
        :conditions => conditions,
        :joins => joins
      }
      
      @soap_operations = ActiveRecord::Base.connection.select_all(SoapOperation.send(:construct_finder_arel, finder_options))
    else
      @soap_operations = SoapOperation.paginate(:page => @page,
                                                :per_page => @per_page,
                                                :order => order,
                                                :conditions => conditions,
                                                :joins => joins)
    end
  end
  
  def find_soap_operation
    # Old Rails 2 style
    #@soap_operation = SoapOperation.find(params[:id], :include => [ :soap_inputs, :soap_outputs ])
    @soap_operation = SoapOperation.includes(:soap_inputs, :soap_outputs).find(params[:id])
  end
  
private

  def get_new_params_with_also_filter
    # TODO: implement ?include=inputs,outputs
    
    # Add SoapOperation filter
    new_params = ServiceCatalographer::Filtering.add_filter_to_params(params, :asop, @soap_operation.id)
    
    # Now add any other filters, if specified by "also=..."
    
    if @api_params[:also].include?('inputs')
      # Old Rails 2 style
      #@soap_operation.soap_inputs.all(:select => "id").each do |input|
      @soap_operation.soap_inputs.select("id").each do |input|
          new_params = ServiceCatalographer::Filtering.add_filter_to_params(new_params, :asin, input.id)
      end
    end
    
    if @api_params[:also].include?('outputs')
      # Old Rails 2 style
      #@soap_operation.soap_outputs.all(:select => "id").each do |output|
      @soap_operation.soap_outputs.select("id").each do |output|
        new_params = ServiceCatalographer::Filtering.add_filter_to_params(new_params, :asout, output.id)
      end
    end
    
    return new_params
  end
  
end
