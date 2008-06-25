class MealsController < ApplicationController
  def index
    list
    render :action => 'list'
  end

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
         :redirect_to => { :action => :list }

  def list
    @meal_pages, @meals = paginate :meals, :per_page => 10
  end

  def show
    @meal = Meal.find(params[:id])
  end

  def new
    @meal = Meal.new
  end

  def create
    @meal = Meal.new(params[:meal])
    if @meal.save
      flash[:notice] = 'Meal was successfully created.'
      redirect_to :action => 'list'
    else
      render :action => 'new'
    end
  end

  def edit
    @meal = Meal.find(params[:id])
  end

  def update
    @meal = Meal.find(params[:id])
    if @meal.update_attributes(params[:meal])
      flash[:notice] = 'Meal was successfully updated.'
      redirect_to :action => 'show', :id => @meal
    else
      render :action => 'edit'
    end
  end

  def destroy
    Meal.find(params[:id]).destroy
    redirect_to :action => 'list'
  end
end
