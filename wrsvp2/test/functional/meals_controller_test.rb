require File.dirname(__FILE__) + '/../test_helper'
require 'meals_controller'

# Re-raise errors caught by the controller.
class MealsController; def rescue_action(e) raise e end; end

class MealsControllerTest < Test::Unit::TestCase
  fixtures :meals

  def setup
    @controller = MealsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @first_id = meals(:first).id
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'list'
  end

  def test_list
    get :list

    assert_response :success
    assert_template 'list'

    assert_not_nil assigns(:meals)
  end

  def test_show
    get :show, :id => @first_id

    assert_response :success
    assert_template 'show'

    assert_not_nil assigns(:meal)
    assert assigns(:meal).valid?
  end

  def test_new
    get :new

    assert_response :success
    assert_template 'new'

    assert_not_nil assigns(:meal)
  end

  def test_create
    num_meals = Meal.count

    post :create, :meal => {}

    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_equal num_meals + 1, Meal.count
  end

  def test_edit
    get :edit, :id => @first_id

    assert_response :success
    assert_template 'edit'

    assert_not_nil assigns(:meal)
    assert assigns(:meal).valid?
  end

  def test_update
    post :update, :id => @first_id
    assert_response :redirect
    assert_redirected_to :action => 'show', :id => @first_id
  end

  def test_destroy
    assert_nothing_raised {
      Meal.find(@first_id)
    }

    post :destroy, :id => @first_id
    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_raise(ActiveRecord::RecordNotFound) {
      Meal.find(@first_id)
    }
  end
end
