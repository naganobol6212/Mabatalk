# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_05_07_034933) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_summaries", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "content", null: false
    t.datetime "generated_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_ai_summaries_on_user_id", unique: true
  end

  create_table "feedbacks", force: :cascade do |t|
    t.bigint "user_id"
    t.integer "category", default: 0, null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_feedbacks_on_user_id"
  end

  create_table "flow_items", force: :cascade do |t|
    t.bigint "user_id"
    t.string "key", null: false
    t.string "name", null: false
    t.string "kana", null: false
    t.string "icon", null: false
    t.string "icon_color", default: "gray", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "message_category_id"
    t.string "detail_flow_key"
    t.index ["key"], name: "index_flow_items_on_key", unique: true
    t.index ["message_category_id"], name: "index_flow_items_on_message_category_id"
    t.index ["user_id"], name: "index_flow_items_on_user_id"
  end

  create_table "message_categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "kana", null: false
    t.string "icon", null: false
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "key"
    t.string "icon_color", default: "gray", null: false
    t.integer "position", default: 0, null: false
    t.index ["key"], name: "index_message_categories_on_key", unique: true
    t.index ["user_id"], name: "index_message_categories_on_user_id"
  end

  create_table "message_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "flow_item_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "message_category_name"
    t.string "flow_item_name"
    t.string "flow_item_icon"
    t.string "flow_item_icon_color"
    t.string "message_category_icon_color"
    t.string "detail_flow_text"
    t.jsonb "detail_flow_data"
    t.index ["flow_item_id"], name: "index_message_logs_on_flow_item_id"
    t.index ["user_id"], name: "index_message_logs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "provider"
    t.string "uid"
    t.string "name"
    t.boolean "admin", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_summaries", "users"
  add_foreign_key "feedbacks", "users"
  add_foreign_key "flow_items", "message_categories"
  add_foreign_key "flow_items", "users"
  add_foreign_key "message_categories", "users"
  add_foreign_key "message_logs", "flow_items"
  add_foreign_key "message_logs", "users"
end
