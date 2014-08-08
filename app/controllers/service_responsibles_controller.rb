# ServiceCatalographer: app/controllers/service_responsibles_controller.rb
#
# Copyright (c) 2010, University of Manchester, The European Bioinformatics
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details.

class ServiceResponsiblesController < ApplicationController
  
  before_filter :find_service_responsible, :only => [:activate, :deactivate, :destroy]
  
  before_filter :login_required, :only =>[:activate, :deactivate, :destroy]
  
  before_filter :authorise, :only => [:activate, :deactivate, :destroy]
  
  def destroy
    respond_to do |format|
      if @service_responsible.destroy
        flash[:notice] = "Removed from the responsbility list for the service: '#{@service_responsible.service.name}'"
        format.html { redirect_to_back_or_home }
        format.xml  { head :ok }
      else
        flash[:error] = "Failed to remove you from the responsbility list. Please contact us for more assistance."
        format.html { redirect_to service_url(@service) }
      end
    end
  end
  
  def deactivate
    respond_to do |format|
      if @service_responsible.deactivate!
        flash[:notice] = "You have been removed from the status notification list for #{@service_responsible.service.name}"
        format.html{redirect_to(user_url(@service_responsible.user, :id => @service_responsible.user.id, :anchor =>'status-notifications')) }
        format.xml { disable_action }
      else
        flash[:notice] = "Could not remove you from status notification list for #{@service_responsible.service.name}"
        format.html{redirect_to(user_url(@service_responsible.user, :id => @service_responsible.user.id, :anchor =>'status-notifications')) }
        format.xml { disable_action }
      end
    end
  end
  
  def activate
    respond_to do |format|
      if @service_responsible
        if @service_responsible.activate!
          flash[:notice] = "You have been added to status notification list for #{@service_responsible.service.name}"
          format.html{ redirect_to(user_url(@service_responsible.user, :id => @service_responsible.user.id, :anchor =>'status-notifications')) }
          format.xml { disable_action }
        else
          flash[:error] = "Could not add you to the status notification list for #{@service_responsible.service.name}"
          format.html{ redirect_to(user_url(@service_responsible.user, :id => @service_responsible.user.id, :anchor =>'status-notifications')) }
          format.xml { disable_action }
        end
      end
    end
  end

  private 
  
  def find_service_responsible
    @service_responsible = ServiceResponsible.find(params[:id])
  end
  
  def authorise
    unless ServiceCatalographer::Auth.allow_user_to_curate_thing?(current_user, @service_responsible.service)
      flash[:error] = "You are not allowed to perform this action!"
      redirect_to @service_responsible.service
    end
  end

end
