import Chart from 'vendor/Chart';

document.addEventListener('DOMContentLoaded', () => {
  const projectChartData = JSON.parse(document.getElementById('projectChartData').innerHTML);

  const responsiveChart = (selector, data) => {
    const options = {
      scaleOverlay: true,
      responsive: true,
      pointHitDetectionRadius: 2,
      maintainAspectRatio: false,
    };
    // get selector by context
    const ctx = selector.get(0).getContext('2d');
    // pointing parent container to make chart.js inherit its width
    const container = $(selector).parent();
    const generateChart = () => {
      selector.attr('width', $(container).width());
      if (window.innerWidth < 768) {
        // Scale fonts if window width lower than 768px (iPad portrait)
        options.scaleFontSize = 8;
      }
      return new Chart(ctx).Bar(data, options);
    };
    // enabling auto-resizing
    $(window).resize(generateChart);
    return generateChart();
  };

  const chartData = (keys, values) => {
    const data = {
      labels: keys,
      datasets: [{
        fillColor: 'rgba(220,220,220,0.5)',
        strokeColor: 'rgba(220,220,220,1)',
        barStrokeWidth: 1,
        barValueSpacing: 1,
        barDatasetSpacing: 1,
        data: values,
      }],
    };
    return data;
  };

  const hourData = chartData(projectChartData.hour.keys, projectChartData.hour.values);
  responsiveChart($('#hour-chart'), hourData);

  const dayData = chartData(projectChartData.weekDays.keys, projectChartData.weekDays.values);
  responsiveChart($('#weekday-chart'), dayData);

  const monthData = chartData(projectChartData.month.keys, projectChartData.month.values);
  responsiveChart($('#month-chart'), monthData);

  const data = projectChartData.languages;
  const ctx = $('#languages-chart').get(0).getContext('2d');
  const options = {
    scaleOverlay: true,
    responsive: true,
    maintainAspectRatio: false,
  };

  new Chart(ctx).Pie(data, options);
});
