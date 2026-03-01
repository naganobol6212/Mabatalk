import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static values = { data: Array }

  connect() {
    const labels = this.dataValue.map(d => d.label)
    const counts = this.dataValue.map(d => d.count)
    const colors = this.dataValue.map(d => this.categoryColor(d.color))

    new Chart(this.element, {
      type: "bar",
      data: {
        labels,
        datasets: [{ data: counts, backgroundColor: colors }]
      },
      options: {
        indexAxis: "y",
        responsive: true,
        plugins: { legend: { display: false } },
        scales: { x: { ticks: { stepSize: 1 }, beginAtZero: true } }
      }
    })
  }

  categoryColor(key) {
    const map = {
      red:     "#ef4444", orange:  "#f97316", amber:   "#f59e0b",
      yellow:  "#eab308", lime:    "#84cc16", green:   "#22c55e",
      emerald: "#10b981", cyan:    "#06b6d4", sky:     "#0ea5e9",
      blue:    "#3b82f6", indigo:  "#6366f1", violet:  "#8b5cf6",
      pink:    "#ec4899", rose:    "#f43f5e", gray:    "#9ca3af",
    }
    return map[key] ?? "#9ca3af"
  }
}
