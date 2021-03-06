class Admin::CustomTextsController < ApplicationController
  before_filter :admin_login_required

  def index
    @custom_texts = CustomText.find :all

    respond_to do |format|
      format.html
      format.xml  { render :xml => @custom_texts.to_xml }
    end
  end

  def show
    @custom_text = CustomText.find(params[:id])
    respond_to do |format|
      format.html
      format.xml  { render :xml => @custom_text.to_xml }
    end
  end

  def new
    @custom_text = CustomText.new
  end

  def create
    @custom_text = CustomText.new(params[:custom_text])
    respond_to do |format|
      if @custom_text.save
        flash[:notice] = "Custom text successfully created"
        format.html { redirect_to custom_text_url(@custom_text) }
      else
        flash[:error] = "Problems creating your new custom text"
        format.html { render :action => :new }
      end
    end
  end

  def edit
    @custom_text = CustomText.find(params[:id])
    respond_to do |format|
      format.html
    end
  end

  def update
    @custom_text = CustomText.find(params[:id])
    if @custom_text.update_attributes(params[:custom_text])
      flash[:notice] = "Details have been updated"
      redirect_to custom_text_url(@custom_text)
    else
      flash[:error] = "Failed to update attributes"
      render :action => "edit", :id => @custom_text.id
    end
  end

  def destroy
    custom_text = CustomText.find(params[:id])
    if custom_text.destroy
      flash[:notice] = "Custom text deleted"
    else
      flash[:notice] = "Failed to destroy custom text"
    end
    redirect_to custom_texts_url
  end

end
