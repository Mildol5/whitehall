require "test_helper"

class Admin::DocumentCollectionEmailSubscriptionsControllerTest < ActionController::TestCase
  include TaxonomyHelper
  setup do
    @collection = create(:draft_document_collection, :with_group)
    @user_with_permission = create(:writer, permissions: [User::Permissions::EMAIL_OVERRIDE_EDITOR])
    @user_without_permission = create(:writer)
    @selected_taxon_content_id = root_taxon_content_id
    @put_params = {
      document_collection_id: @collection.id,
      override_email_subscriptions: "true",
      selected_taxon_content_id: @selected_taxon_content_id,
      email_override_confirmation: "true",
    }
    login_as @user_without_permission
    stub_publishing_api_has_item(content_id: root_taxon_content_id, title: root_taxon["title"])
    stub_taxonomy_with_all_taxons
  end

  should_be_an_admin_controller

  view_test "GET #edit renders successfully when the user has the relevant permission" do
    login_as @user_with_permission
    get :edit, params: { document_collection_id: @collection.id }
    assert_response :ok
    assert_select "div", /You cannot change the email notifications for this document collection/
  end

  test "GET #edit redirects to the edit page when the user does not have permission" do
    login_as @user_without_permission
    get :edit, params: { document_collection_id: @collection.id }
    assert_redirected_to edit_admin_document_collection_path(@collection)
  end

  test "PUT #edit successfully updates a document collection when the user has permission" do
    login_as @user_with_permission
    put :update, params: @put_params
    @collection.reload

    assert_equal @collection.taxonomy_topic_email_override, @selected_taxon_content_id
    assert_redirected_to edit_admin_document_collection_path(@collection)
  end

  test "PUT #edit does not update a document collection when the user does not have permission" do
    login_as @user_without_permission
    put :update, params: @put_params
    @collection.reload

    assert_nil @collection.taxonomy_topic_email_override
    assert_redirected_to edit_admin_document_collection_path(@collection)
  end

  test "PUT #edit does not update a document collection when the confirmation field is not present" do
    login_as @user_with_permission
    put :update, params: @put_params.reject { |k| k == :email_override_confirmation }
    @collection.reload

    selected = { override_email_subscriptions: "true", selected_taxon_content_id: @selected_taxon_content_id }

    assert_nil @collection.taxonomy_topic_email_override
    assert_redirected_to admin_document_collection_edit_email_subscription_path(@collection, selected)
  end

  test "PUT #edit does not update a document collection when the selected_taxon_content_id field is not present" do
    login_as @user_with_permission
    put :update, params: @put_params.reject { |k| k == :selected_taxon_content_id }
    @collection.reload

    selected = { override_email_subscriptions: "true" }

    assert_nil @collection.taxonomy_topic_email_override
    assert_redirected_to admin_document_collection_edit_email_subscription_path(@collection, selected)
  end

  test "PUT #edit does not update taxonomy topic override of a published document collection" do
    login_as @user_with_permission
    collection = create(:published_document_collection, taxonomy_topic_email_override: "a-uuid")
    put :update, params: @put_params.merge(document_collection_id: collection.id)
    assert_redirected_to edit_admin_document_collection_path(collection)

    collection.reload
    assert_equal "a-uuid", collection.taxonomy_topic_email_override
  end

  test "PUT #edit successfully updates taxonomy topic override of a draft document collection" do
    login_as @user_with_permission
    collection = create(:draft_document_collection, taxonomy_topic_email_override: @selected_taxon_content_id)

    params = {
      document_collection_id: collection.id,
      override_email_subscriptions: "false",
    }

    put(:update, params:)
    collection.reload

    assert_nil collection.taxonomy_topic_email_override
    assert_redirected_to edit_admin_document_collection_path(collection)
  end
end
