require_dependency 'stash_datacite/application_controller'

module StashDatacite
  class GeolocationBoxesController < ApplicationController
    before_action :set_geolocation_box, only: [:show, :edit, :update, :delete]

    # # GET /geolocation_boxes/
    def boxes_coordinates
      @geolocation_boxes = GeolocationBox.select(:sw_latitude,
                                                 :sw_longitude, :ne_latitude,
                                                 :ne_longitude).where(resource_id: params[:resource_id])
      respond_to do |format|
        format.html
        format.json { render json: @geolocation_boxes }
      end
    end

    # # GET /geolocation_boxes/1/edit
    # def edit
    # end

    # POST /geolocation_boxes
    def map_coordinates
      geolocation_box_params = params.except(:controller, :action)
      @geolocation_box = GeolocationBox.new(geolocation_box_params.permit!)
      respond_to do |format|
        if @geolocation_box.save
          @resource = StashDatacite.resource_class.find(params[:resource_id])
          @geolocation_boxes = GeolocationBox.where(resource_id: params[:resource_id])
          format.js { render template: 'stash_datacite/geolocation_boxes/create.js.erb' }
        else
          format.html { render :new }
        end
      end
    end

    # POST /geolocation_boxes
    def create
      @geolocation_box = GeolocationBox.new(geolocation_box_params)
      respond_to do |format|
        if @geolocation_box.save
          @resource = StashDatacite.resource_class.find(geolocation_box_params[:resource_id])
          @geolocation_boxes = GeolocationBox.where(resource_id: geolocation_box_params[:resource_id])
          format.js
        else
          format.html { render :new }
        end
      end
    end

    # DELETE /geolocation_boxes/1
    def delete
      @sw_latitude = @geolocation_box.sw_latitude
      @sw_longitude = @geolocation_box.sw_longitude
      @ne_latitude = @geolocation_box.ne_latitude
      @ne_longitude = @geolocation_box.ne_longitude
      @geolocation_box.destroy
      @resource = StashDatacite.resource_class.find(params[:resource_id])
      @geolocation_boxes = GeolocationBox.where(resource_id: params[:resource_id])
      respond_to do |format|
        format.js
      end
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_geolocation_box
      @geolocation_box = GeolocationBox.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def geolocation_box_params
      params.require(:geolocation_box).permit(:sw_latitude, :sw_longitude, :ne_latitude,
                                              :ne_longitude, :resource_id)
    end
  end
end
