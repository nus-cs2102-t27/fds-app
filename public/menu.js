const rid = (new URL(location.href)).searchParams.get("rid");
const prices = {};
const quantity = {};
let deliveryFee = 0.0;

$("#rid-input").val(rid);
$("#restaurant-name").load(`/api/res/${rid}/name`);

$.ajax("/api/cust/locations", { dataType: "json" }).done(locations => {
    locations.forEach(l => {
        $("#last-five-locations").append(`
            <option>${l.lastfivelocations}</option>
        `)
    });
})

function updateTotalCost() {
    let total = deliveryFee;
    for (let fid in quantity) {
        total += quantity[fid] * prices[fid];
    }
    $("#total-price").html(total.toFixed(2));
}

// can load it somewhere first?? thats what i tried but then i think i screwed up
$.ajax(`/api/res/${rid}/deliveryfee`).done(fee => {
    deliveryFee = parseFloat(fee);
    $("#delivery-fee").text(deliveryFee.toFixed(2));
    updateTotalCost();
});

$("#acc-points").load(`/api/cust/points`);
        
$.ajax("/api/menu/" + rid, { dataType: "json" }).done(menu => {
    menu.forEach(food => {

        prices[food.fid] = food.price;
        
        $("#food").append(`
            <tr id="row-${food.fid}">
              <td>${food.name}</td>
              <td>$${food.price}</td>
              <td><input id="input-${food.fid}" class="number-input" type="number" name="${food.fid}" min=0 max=${food.food_left} step=1 value=0></input></td>
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
