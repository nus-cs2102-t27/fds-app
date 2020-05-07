$.ajax(`/api/sum/custOrder`, { dataType: "json" }).done(rows => {
    rows.forEach(row => {
        $("#cust").append(`
            <tr>
              <td>${row.uid}</td>
              <td>${row.name}</td>
              <td>${monthNames[row.month]}</td>
              <td>${row.orders}</td>
              <td>$${row.costs}</td>
            </tr>
        `);
    })
})

const monthNames = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];