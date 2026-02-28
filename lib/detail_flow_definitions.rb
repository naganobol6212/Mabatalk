module DetailFlowDefinitions
  # key はそのまま flow_items.detail_flow_key に保存される。
  # 既存 key の削除・変更禁止（既存 DB データが孤立する）。
  # label: スナップショット文生成用（i18n に移した question とは別）
  # question: config/locales/ja.yml の detail_flows.<flow_key>.<step_key>.question に移動済み
  FLOWS = {
    # 飲みもの全般（量 → 温度）
    "drink_detail" => {
      label: "飲みものの詳細",
      steps: [
        {
          key: "amount",
          label: "量",
          choices: [
            { value: "small",  label: "少し" },
            { value: "medium", label: "普通" },
            { value: "large",  label: "多め" }
          ]
        },
        {
          key: "temperature",
          label: "温度",
          choices: [
            { value: "cold",     label: "冷たい" },
            { value: "room",     label: "常温" },
            { value: "lukewarm", label: "ぬるめ" },
            { value: "hot",      label: "温かい" }
          ]
        }
      ]
    },

    # 飲みもの（量のみ）
    "drink_amount_detail" => {
      label: "飲みものの量",
      steps: [
        {
          key: "amount",
          label: "量",
          choices: [
            { value: "small",  label: "少し" },
            { value: "medium", label: "普通" },
            { value: "large",  label: "多め" }
          ]
        }
      ]
    },

    # 痛い（どこが？）
    "pain_detail" => {
      label: "痛みの詳細",
      steps: [
        {
          key: "place",
          label: "場所",
          choices: [
            { value: "head",  label: "頭" },
            { value: "neck",  label: "首・肩" },
            { value: "chest", label: "胸" },
            { value: "belly", label: "お腹" },
            { value: "back",  label: "背中" },
            { value: "waist", label: "腰" },
            { value: "arms",  label: "手・腕" },
            { value: "legs",  label: "足" }
          ]
        }
      ]
    },

    # かゆい（どこが？）
    "itch_detail" => {
      label: "かゆみの詳細",
      steps: [
        {
          key: "place",
          label: "場所",
          choices: [
            { value: "face",  label: "顔" },
            { value: "head",  label: "頭" },
            { value: "back",  label: "背中" },
            { value: "belly", label: "お腹" },
            { value: "arms",  label: "手・腕" },
            { value: "legs",  label: "足" }
          ]
        }
      ]
    },

    # 暑い（どうする？）
    "hot_detail" => {
      label: "暑さへの対応",
      steps: [
        {
          key: "action",
          label: "対応",
          choices: [
            { value: "aircon",  label: "冷房を強くする" },
            { value: "fan",     label: "扇風機をつける" },
            { value: "clothes", label: "服をゆるめる" },
            { value: "window",  label: "窓を開ける" }
          ]
        }
      ]
    },

    # 寒い（どうする？）
    "cold_detail" => {
      label: "寒さへの対応",
      steps: [
        {
          key: "action",
          label: "対応",
          choices: [
            { value: "heater",  label: "暖房を強くする" },
            { value: "blanket", label: "毛布を増やす" },
            { value: "clothes", label: "服を着る" },
            { value: "window",  label: "窓を閉める" }
          ]
        }
      ]
    },

    # ベッドの角度調整
    "bed_detail" => {
      label: "ベッド操作",
      steps: [
        {
          key: "action",
          label: "操作",
          choices: [
            { value: "upper_up",   label: "上半身を起こす" },
            { value: "upper_down", label: "上半身を下げる" },
            { value: "whole_up",   label: "全体を上げる" },
            { value: "whole_down", label: "全体を下げる" }
          ]
        }
      ]
    },

    # 室温の調整
    "room_temp_detail" => {
      label: "室温の調整",
      steps: [
        {
          key: "action",
          label: "室温",
          choices: [
            { value: "up",   label: "上げる" },
            { value: "down", label: "下げる" }
          ]
        }
      ]
    },

    # 明かりの調整
    "light_detail" => {
      label: "明かりの調整",
      steps: [
        {
          key: "action",
          label: "操作",
          choices: [
            { value: "on",     label: "つける" },
            { value: "off",    label: "消す" },
            { value: "bright", label: "明るくする" },
            { value: "dim",    label: "暗くする" }
          ]
        }
      ]
    }
  }.freeze

  def self.find(key)
    FLOWS[key]
  end
end
