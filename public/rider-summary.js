$.ajax(`/api/sum/riderSumm`, { dataType: "json" }).done(rows => {
    rows.forEach(row => {
        $("#cust").append(`
            <tr>
            <td>${row.uid}</td>
            <td>${row.name}</td>
            <td>${monthNames[row.month]}</td>
            <td>${row.orders_delivered}</td>
            <td>${row.hours_worked}</td>
            <td>${row.average_delivery_time}</td>
            <td>${row.monthly_salary}</td>
            <td>${row.ratings}</td>
            </tr>
        `);
    })
})

const monthNames = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];