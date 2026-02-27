class SetIconColorDefaultAndNotNull < ActiveRecord::Migration[7.2]
  COLOR_CLASS_TO_KEY = {
    "text-orange-500"  => "orange",
    "text-orange-600"  => "orange",
    "text-amber-500"   => "amber",
    "text-yellow-500"  => "amber",
    "text-cyan-500"    => "cyan",
    "text-cyan-600"    => "cyan",
    "text-indigo-500"  => "indigo",
    "text-blue-600"    => "indigo",
    "text-blue-400"    => "sky",
    "text-sky-500"     => "sky",
    "text-sky-600"     => "sky",
    "text-emerald-500" => "emerald",
    "text-emerald-600" => "emerald",
    "text-green-600"   => "emerald",
    "text-rose-400"    => "rose",
    "text-rose-500"    => "rose",
    "text-red-600"     => "rose",
    "text-violet-500"  => "violet",
    "text-purple-500"  => "violet",
    "text-gray-400"    => "gray",
    "text-slate-600"   => "gray"
    }.freeze

    def up
      # 旧 Tailwind クラス形式を semantic key に変換
      COLOR_CLASS_TO_KEY.each do |old_class, key|
        FlowItem.where(icon_color: old_class).update_all(icon_color: key)
        MessageCategory.where(icon_color: old_class).update_all(icon_color: key)
      end

      # 残った nil を "gray" で埋める
      FlowItem.where(icon_color: nil).update_all(icon_color: "gray")
      MessageCategory.where(icon_color: nil).update_all(icon_color: "gray")

      change_column_default :flow_items, :icon_color, from: nil, to: "gray"
      change_column_default :message_categories, :icon_color, from: nil, to: "gray"

      change_column_null :flow_items, :icon_color, false
      change_column_null :message_categories, :icon_color, false
    end

    def down
      raise ActiveRecord::IrreversibleMigration
    end
end
