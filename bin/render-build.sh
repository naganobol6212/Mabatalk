set -o errexit

bundle install
bundle exec rails assets:precompile
bundle exec rails assets:clean

# migration 時のみ Direct URL を使う（NeonDB PgBouncer 回避）
DATABASE_URL="$DATABASE_URL_DIRECT" bundle exec rails db:migrate
