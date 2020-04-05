fetch("/api/health").then(res => res.text()).then(health => {
    console.log(health);
    document.getElementById("health").innerHTML = health;
});
