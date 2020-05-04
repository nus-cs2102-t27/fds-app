function getDaysToNextMon(day_today) {
    if (day_today === 0) {
        return 8;
    } else {
        return 15 - day_today;
    }
} 

function addDays(val, date) {
    const temp_date = new Date(date);
    temp_date.setDate(temp_date.getDate() + val);
    return temp_date;
}

function getWorkDate(val) {
    const today = new Date();
    const day_today = today.getDay();
    const days_to_add = getDaysToNextMon(day_today) + parseInt(val);
    const date = addDays(days_to_add, today);
    return date.getDate() + '/' + (date.getMonth()+1) + '/' + date.getFullYear();
}

const dayOfWeek = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
dayOfWeek.forEach((val, index) => {
    $("#log-hours-table").append(`
    <tr>
        <td>
          <div>${val}</div>
          <div>${getWorkDate(index)}</div>
        </td>
        <td><input type="text" name="start-1-${index}" size="6"/> - <input type="text" name="end-1-${index}" size="6"/></td>
        <td><input type="text" name="start-2-${index}" size="6"/> - <input type="text" name="end-2-${index}" size="6"/></td>
        <td><input type="text" name="start-3-${index}" size="6"/> - <input type="text" name="end-3-${index}" size="6"/></td>
        <td><input type="text" name="start-4-${index}" size="6"/> - <input type="text" name="end-4-${index}" size="6"/></td>
    </tr>`)
})