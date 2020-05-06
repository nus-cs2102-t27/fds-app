$.ajax(`/api/ptridersum/ptrider`, { dataType: "json" }).done(rows => {
    rows.forEach(row => {
        $("#ptrider").append(`
            <tr>
              <td>${row.hoursWorked}</td>
              <td>${row.weekly_base_salary}</td>
              <td>${row.weekly_base_salary}</td>
            </tr>
        `);
    })
})

const monthNames = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];