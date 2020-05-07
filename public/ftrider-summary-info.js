$.ajax(`/api/ftridersum/ftrider`, { dataType: "json" }).done(rows => {
    rows.forEach(row => {
        $("#ftrider").append(`
            <tr>
              <td>${row.monthly_orders}</td>
              <td>${row.hours_worked}</td>
              <td>${row.monthly_base_salary}</td>
              <td>${row.lifetime_salary}</td>
            </tr>
        `);
    })
})

const monthNames = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];