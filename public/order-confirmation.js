const rid = (new URL(location.href)).searchParams.get("rid");
const prices = {};
const quantity = {};

$("#rid-input").val(rid);
$("#restaurant-name").load(`/api/res/${rid}/name`);

function updateTotalCost() {
    let total = 0;
    for (let fid in quantity) {
        total += quantity[fid] * prices[fid];
    }
    $("#total-price").html(total.toFixed(2));
}
updateTotalCost();
        
$.ajax("/api/menu/" + rid, { dataType: "json" }).done(menu => {
    menu.forEach(food => {

        prices[food.fid] = food.price;
        
        $("#food").append(`
            <tr id="row-${food.fid}">
              <td>${food.name}</td>
              <td>$${food.price}</td>
              <td><input id="input-${food.fid}" class="number-input" type="number" name="${food.fid}" min=0 step=1 value=0></input></td>
            </tr>
        `)

        $("#input-" + food.fid).change(() => {

            const qty = $("#input-" + food.fid).val();
            quantity[food.fid] = qty;
            updateTotalCost();

            if (qty > 0) {
                $("#row-" + food.fid).css("background", "#eee");
            } else {
                $("#row-" + food.fid).css("background", "inherit");
            }    
        })
    })
})
