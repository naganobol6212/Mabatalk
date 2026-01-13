require "test_helper"

class MessageCategoriesControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get message_categories_new_url
    assert_response :success
  end

  test "should get create" do
    get message_categories_create_url
    assert_response :success
  end
end
