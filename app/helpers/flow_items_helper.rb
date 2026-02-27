module FlowItemsHelper
  def flow_item_icons
    IconDefinitions::FLOW_ITEM_ICONS
  end
  # グループ別ハッシュ（icon_picker で使用）
  # 戻り値: { "飲みもの" => { "water_drop" => { group: :drink }, ... }, ... }
  def flow_item_icons_by_group
    group_labels = IconDefinitions::FLOW_ITEM_ICON_GROUPS
    IconDefinitions::FLOW_ITEM_ICONS
      .group_by { |_, attrs| attrs[:group] }
      .transform_keys { |group_key| group_labels[group_key] }
      .transform_values { |icons| icons.to_h }
  end
end
