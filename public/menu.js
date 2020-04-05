const rid = (new URL(location.href)).searchParams.get("rid");
$.ajax("/api/menu/" + rid, { dataType: "json" }).done(menu => {
    menu.forEach(food => {
        $("#food").append('<tr><td>' + food.name + '</td><td>$' + food.price + '</td><td><input class="number-input" type="number" name="' + food.fid + '" min=0 step=1 value=0></input></td></tr>')
    })
})
