const rid = (new URL(location.href)).searchParams.get("rid");
const prices = {};
const quantity = {};
let deliveryFee = 0.0;
let acc_points = 0;

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

$("#min-amt").load(`/api/res/${rid}/minamt`);

$.ajax(`/api/res/${rid}/deliveryfee`).done(fee => {
    deliveryFee = parseFloat(fee);
    $("#delivery-fee").text(deliveryFee.toFixed(2));
    updateTotalCost();
});

$.ajax("/api/cust/points").done(points => {
    acc_points = points;
    console.log(deliveryFee);
    console.log(acc_points);
    $("#acc-points").text(acc_points);
    $("#points").append(`
        <input type="number" class="text-input-field" name="usedpoints" min=0 max=${Math.min(acc_points, deliveryFee * 100)} placeholder="Optional"></input>`
    );
});
        
$.ajax("/api/menu/" + rid, { dataType: "json" }).done(menu => {
    menu.forEach(food => {

        prices[food.fid] = food.price;
        $("#food").append(`
            ${food.food_left === '0' ? 
                `<tr>
                   <td>${food.name} <span class="text-danger">(unavailable)</span></td>
                   <td>$${food.price}</td>
                   <td><input disabled id="input-${food.fid}" class="number-input" type="number" name="${food.fid}" min=0 max=${food.food_left} step=1 value=0></input></td>
                 </tr>` :
                `<tr id="row-${food.fid}">
                   <td>${food.name}</td>
                   <td>$${food.price}</td>
                   <td><input id="input-${food.fid}" class="number-input" type="number" name="${food.fid}" min=0 max=${food.food_left} step=1 value=0></input></td>
                 </tr>`}
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
