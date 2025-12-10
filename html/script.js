let currentBench = null;
let selectedRecipe = null;
let playerLevel = 1;
let playerXP = 0;
let nextLevelXP = 100;
let recipes = {};
let playerInventory = {};
let craftQuantity = 1;
let maxCraftable = 1;
let craftingQueue = [];

let isRepairMode = false;
let selectedWeapon = null;
let playerWeapons = [];
let repairCosts = {};

$(document).ready(function() {
    window.addEventListener('message', function(event) {
        const data = event.data;
        console.log('NUI Message:', data.action);
        
        if (data.action === 'open') {
            openCraftingMenu(data);
        } else if (data.action === 'close') {
            closeCraftingMenu();
        } else if (data.action === 'updateQueue') {
            updateCraftingQueue(data.queue);
        } else if (data.action === 'updateStats') {
            playerLevel = data.level;
            playerXP = data.xp;
            nextLevelXP = data.nextLevelXP;
            updatePlayerStats();
        } else if (data.action === 'openRepairMenu') {
            openRepairMenu(data);
        } else if (data.action === 'updateInventory') {
            playerInventory = data.inventory || {};
            console.log('Inventory updated:', playerInventory);
            
            if (selectedRecipe) {
                updateSelectedItemInfo();
            }
            
            if (isRepairMode && selectedWeapon) {
                updateRepairDetails();
            }
        } else if (data.action === 'updateSelectedRecipe') {
            if (data.item && recipes[data.item]) {
                selectedRecipe = data.item;
                updateSelectedItemInfo();
            }
        }
    });

    $('#close-menu').click(function() {
        closeCraftingMenu();
    });

    $('#craft-btn').click(function() {
        console.log('Craft button clicked');
        console.log('Selected recipe:', selectedRecipe);
        console.log('Current bench:', currentBench);
        console.log('Current quantity:', craftQuantity);
        
        if (selectedRecipe && currentBench) {
            const quantityInput = $('#craft-quantity');
            let quantity = parseInt(quantityInput.val()) || 1;
            
            if (quantity < 1 || quantity > 100) {
                alert('Quantity must be between 1 and 100');
                quantityInput.val(1);
                quantity = 1;
                return;
            }
            
            if (quantity > maxCraftable) {
                alert(`You can only craft ${maxCraftable} with your current materials`);
                quantityInput.val(maxCraftable);
                quantity = maxCraftable;
                return;
            }
            
            console.log('Sending craft request:', {
                item: selectedRecipe,
                quantity: quantity,
                benchType: currentBench.name
            });
            
            $.post('https://ml187-crafting/craftItem', JSON.stringify({
                item: selectedRecipe,
                quantity: quantity,
                benchType: currentBench.name
            }), function(response) {
                console.log('Craft response:', response);
                if (response === 'ok') {
                    craftQuantity = 1;
                    updateQuantityDisplay();
                }
            }).fail(function(error) {
                console.error('Craft request failed:', error);
            });
        } else {
            console.error('Cannot craft: missing selectedRecipe or currentBench');
            if (!selectedRecipe) console.error('No recipe selected');
            if (!currentBench) console.error('No current bench');
        }
    });

    $(document).on('click', '.queue-cancel', function() {
        const queueId = $(this).data('id');
        $.post('https://ml187-crafting/cancelCrafting', JSON.stringify({
            queueId: queueId
        }));
    });

    $(document).keyup(function(e) {
        if (e.key === "Escape") {
            closeCraftingMenu();
        }
    });
    
    $('#repair-toggle').click(function() {
        toggleRepairMode();
    });
    
    $('#repair-btn').click(function() {
        if (selectedWeapon && currentBench) {
            $.post('https://ml187-crafting/repairWeapon', JSON.stringify({
                weaponHash: selectedWeapon.slot,
                benchType: currentBench.name
            }));
            
            selectedWeapon = null;
            updateRepairDetails();
            
            toggleRepairMode();
        }
    });
    
    $(document).on('click', '.weapon-item', function() {
        if ($(this).hasClass('locked')) return;
        
        const weaponIndex = $(this).data('index');
        $('.weapon-item').removeClass('selected');
        $(this).addClass('selected');
        selectedWeapon = playerWeapons[weaponIndex];
        updateRepairDetails();
    });
});

function openCraftingMenu(data) {
    currentBench = data.bench;
    playerLevel = data.level;
    playerXP = data.xp;
    nextLevelXP = data.nextLevelXP;
    recipes = data.recipes;
    playerInventory = data.inventory;
    craftingQueue = data.queue || [];
    craftQuantity = 1;
    
    console.log('Opening crafting menu:', {
        benchName: currentBench ? currentBench.name : 'No bench',
        recipesCount: Object.keys(recipes).length,
        inventoryCount: Object.keys(playerInventory).length
    });
    
    $('#bench-name').text(currentBench ? currentBench.name : 'Unknown Bench');
    
    updatePlayerStats();
    populateRecipes();
    updateCraftingQueue(craftingQueue);
    
    isRepairMode = false;
    $('#repair-menu').hide();
    $('#crafting-content').show();
    $('#repair-toggle').html('<i class="fas fa-wrench"></i> Repair');
    
    $('body').fadeIn(300);
}

function closeCraftingMenu() {
    $('body').fadeOut(300);
    $.post('https://ml187-crafting/closeMenu');
    selectedRecipe = null;
}

function updatePlayerStats() {
    $('#player-level').text(playerLevel);
    
    let xpPercentage = 0;
    if (typeof nextLevelXP === 'number') {
        const prevLevelXP = 0; 
        const levelXPRange = nextLevelXP - prevLevelXP;
        const currentLevelProgress = playerXP - prevLevelXP;
        xpPercentage = (currentLevelProgress / levelXPRange) * 100;
    } else {
        xpPercentage = 100;
    }
    
    $('#xp-progress').css('width', `${xpPercentage}%`);
    $('#xp-text').text(`XP: ${playerXP}/${nextLevelXP === 'Max Level' ? 'Max' : nextLevelXP}`);
}

function populateRecipes() {
    const container = $('#recipes-container');
    container.empty();
    
    if (!currentBench || !currentBench.recipes) {
        container.html('<div class="no-recipes">No bench recipes available</div>');
        return;
    }
    
    const benchRecipes = currentBench.recipes;
    
    if (benchRecipes && benchRecipes.length > 0) {
        benchRecipes.forEach(recipeKey => {
            const recipe = recipes[recipeKey];
            if (!recipe) {
                console.warn(`Recipe not found for key: ${recipeKey}`);
                return;
            }
            
            const isLocked = playerLevel < recipe.levelRequired;
            const itemElement = $(`
                <div class="recipe-item ${isLocked ? 'locked' : ''}" data-item="${recipeKey}">
                    <img src="nui://qb-inventory/html/images/${recipeKey}.png" onerror="this.src='nui://qb-inventory/html/images/placeholder.png'" class="recipe-image">
                    <div class="recipe-name">${recipe.name}</div>
                    <div class="recipe-level">Level ${recipe.levelRequired}</div>
                </div>
            `);
            
            if (!isLocked) {
                itemElement.click(function() {
                    $('.recipe-item').removeClass('selected');
                    $(this).addClass('selected');
                    selectedRecipe = recipeKey;
                    craftQuantity = 1;
                    updateSelectedItemInfo();
                });
            } else {
                itemElement.css('opacity', '0.5');
                itemElement.css('cursor', 'not-allowed');
            }
            
            container.append(itemElement);
        });
    } else {
        container.html('<div class="no-recipes">No recipes available for this bench</div>');
    }
}

function updateSelectedItemInfo() {
    console.log('Updating selected item info for:', selectedRecipe);
    console.log('Current inventory:', playerInventory);
    
    const recipe = recipes[selectedRecipe];
    const materialsContainer = $('#materials-list');
    materialsContainer.empty();
    
    if (!recipe) {
        console.error(`Recipe not found for selected item: ${selectedRecipe}`);
        $('#selected-item-info h3').text('Select an item to craft');
        $('#craft-btn').prop('disabled', true).text('Add to Queue');
        return;
    }
    
    $('#selected-item-info h3').text(recipe.name);
    
    maxCraftable = calculateMaxCraftable(recipe);
    console.log('Max craftable:', maxCraftable);
    
    $('#quantity-section').html(`
        <div class="quantity-controls">
            <span class="quantity-label">Quantity:</span>
            <button id="decrease-quantity" ${craftQuantity <= 1 ? 'disabled' : ''}>-</button>
            <input type="number" id="craft-quantity" value="${craftQuantity}" min="1" max="${Math.min(maxCraftable, 100)}">
            <button id="increase-quantity" ${craftQuantity >= Math.min(maxCraftable, 100) ? 'disabled' : ''}>+</button>
            <span class="max-quantity">(Max: ${Math.min(maxCraftable, 100)})</span>
        </div>
    `);
    
    $('#decrease-quantity').click(function() {
        if (craftQuantity > 1) {
            craftQuantity--;
            updateQuantityDisplay();
        }
    });
    
    $('#increase-quantity').click(function() {
        const currentMax = Math.min(maxCraftable, 100);
        if (craftQuantity < currentMax) {
            craftQuantity++;
            updateQuantityDisplay();
        }
    });
    
    $('#craft-quantity').on('input', function() {
        let value = parseInt($(this).val());
        const currentMax = Math.min(maxCraftable, 100);
        
        if (isNaN(value) || value < 1) {
            value = 1;
        } else if (value > currentMax) {
            value = currentMax;
        }
        craftQuantity = value;
        $(this).val(craftQuantity);
        updateSelectedItemInfo();
    });
    
    let canCraft = true;
    
    for (const [material, amount] of Object.entries(recipe.materials)) {
        const totalNeeded = amount * craftQuantity;
        const playerHas = playerInventory[material] || 0;
        const sufficient = playerHas >= totalNeeded;
        
        console.log(`Material check: ${material}, Needed: ${totalNeeded}, Has: ${playerHas}, Sufficient: ${sufficient}`);
        
        if (!sufficient) canCraft = false;
        
        materialsContainer.append(`
            <div class="material-item ${sufficient ? '' : 'insufficient'}">
                <img src="nui://qb-inventory/html/images/${material}.png" onerror="this.src='nui://qb-inventory/html/images/placeholder.png'" class="material-icon">
                <span class="material-text">${totalNeeded}x ${material} <span class="inventory-count">(${playerHas} available)</span></span>
            </div>
        `);
    }
    
    materialsContainer.append(`
        <div class="material-item xp-gain">
            <i class="fas fa-star" style="color: #f1c40f; margin-right: 10px;"></i>
            <span>+${recipe.xpGained * craftQuantity} XP (${recipe.xpGained} per item)</span>
        </div>
    `);
    
    const buttonText = canCraft ? `Add to Queue (${craftQuantity}x)` : 'Insufficient Materials';
    $('#craft-btn').prop('disabled', !canCraft)
                   .html(`<i class="fas fa-plus" style="margin-right: 5px;"></i>${buttonText}`);
}

function calculateMaxCraftable(recipe) {
    if (!recipe || !recipe.materials) return 1;
    
    let maxAmount = 9999;
    
    for (const [material, amount] of Object.entries(recipe.materials)) {
        const playerHas = playerInventory[material] || 0;
        const canCraft = Math.floor(playerHas / amount);
        maxAmount = Math.min(maxAmount, canCraft);
    }
    
    return Math.max(1, maxAmount);
}

function updateQuantityDisplay() {
    $('#craft-quantity').val(craftQuantity);
    const currentMax = Math.min(maxCraftable, 100);
    $('#decrease-quantity').prop('disabled', craftQuantity <= 1);
    $('#increase-quantity').prop('disabled', craftQuantity >= currentMax);
    
    if (selectedRecipe) {
        updateSelectedItemInfo();
    }
}

function updateCraftingQueue(queue) {
    craftingQueue = queue || [];
    const container = $('#queue-container');
    container.empty();
    
    if (craftingQueue.length === 0) {
        container.html('<div class="queue-empty">No items in queue</div>');
        return;
    }
    
    craftingQueue.forEach(item => {
        const recipe = recipes[item.item];
        const progress = item.progress || 0;
        
        container.append(`
            <div class="queue-item" data-id="${item.id}">
                <img src="nui://qb-inventory/html/images/${item.item}.png" onerror="this.src='nui://qb-inventory/html/images/placeholder.png'" class="queue-item-image">
                <div class="queue-item-info">
                    <div class="queue-item-name">${recipe ? recipe.name : item.item}</div>
                    <div class="queue-item-quantity"><i class="fas fa-cubes"></i> Quantity: ${item.quantity}</div>
                </div>
                <div class="queue-progress-container">
                    <div class="queue-progress-bar">
                        <div class="queue-progress" style="width: ${progress}%"></div>
                    </div>
                    <div class="queue-progress-text">${Math.round(progress)}%</div>
                </div>
                <button class="queue-cancel" data-id="${item.id}"><i class="fas fa-times"></i></button>
            </div>
        `);
    });
}

function toggleRepairMode() {
    isRepairMode = !isRepairMode;
    
    if (isRepairMode) {
        $('#crafting-content').hide();
        $('#repair-menu').show();
        $('#repair-toggle').html('<i class="fas fa-hammer"></i> Craft');
        
        $.post('https://ml187-crafting/openRepairMenu');
    } else {
        $('#repair-menu').hide();
        $('#crafting-content').show();
        $('#repair-toggle').html('<i class="fas fa-wrench"></i> Repair');
        
        selectedWeapon = null;
    }
}

function openRepairMenu(data) {
    playerWeapons = data.weapons || [];
    repairCosts = data.repairCosts || {};
    playerInventory = data.inventory || {};
    playerLevel = data.level || 1;
    
    populateWeaponsList();
    updateRepairDetails();
}

function populateWeaponsList() {
    const container = $('#weapons-list');
    container.empty();
    
    if (!playerWeapons || playerWeapons.length === 0) {
        container.html('<div class="no-weapons">No weapons to repair</div>');
        return;
    }
    
    playerWeapons.forEach((weapon, index) => {
        let conditionColor;
        if (weapon.condition >= 80) {
            conditionColor = '#2ecc71';
        } else if (weapon.condition >= 50) {
            conditionColor = '#f39c12';
        } else {
            conditionColor = '#e74c3c';
        }
        
        const canRepair = repairCosts[weapon.name] && 
                          playerLevel >= repairCosts[weapon.name].levelRequired &&
                          weapon.condition < 100;
        
        const weaponElement = $(`
            <div class="weapon-item ${!canRepair ? 'locked' : ''}" data-index="${index}">
                <img src="nui://qb-inventory/html/images/${weapon.name}.png" onerror="this.src='nui://qb-inventory/html/images/placeholder.png'" class="weapon-image">
                <div class="weapon-name">${weapon.label}</div>
                <div class="weapon-condition">
                    <div class="condition-bar" style="width: ${weapon.condition}%; background-color: ${conditionColor}"></div>
                </div>
                <div class="condition-percent">${weapon.condition}%</div>
            </div>
        `);
        
        if (canRepair) {
            weaponElement.click(function() {
                $('.weapon-item').removeClass('selected');
                $(this).addClass('selected');
                selectedWeapon = weapon;
                updateRepairDetails();
            });
        } else {
            weaponElement.css('opacity', '0.5');
            weaponElement.css('cursor', 'not-allowed');
        }
        
        container.append(weaponElement);
    });
}

function updateRepairDetails() {
    const detailsContainer = $('#repair-details');
    const materialsList = $('#repair-materials-list');
    
    if (!selectedWeapon) {
        detailsContainer.find('h4').text('Select a weapon to repair');
        materialsList.empty();
        $('#repair-btn').prop('disabled', true);
        return;
    }
    
    const repairCost = repairCosts[selectedWeapon.name];
    if (!repairCost) {
        detailsContainer.find('h4').text('This weapon cannot be repaired');
        materialsList.empty();
        $('#repair-btn').prop('disabled', true);
        return;
    }
    
    detailsContainer.find('h4').text(`Repair ${selectedWeapon.label} (${selectedWeapon.condition}%)`);
    materialsList.empty();
    
    let canRepair = true;
    
    for (const [material, amount] of Object.entries(repairCost.materials)) {
        const playerHas = playerInventory[material] || 0;
        const sufficient = playerHas >= amount;
        
        if (!sufficient) canRepair = false;
        
        materialsList.append(`
            <div class="material-item ${sufficient ? '' : 'insufficient'}">
                <img src="nui://qb-inventory/html/images/${material}.png" onerror="this.src='nui://qb-inventory/html/images/placeholder.png'" class="material-icon">
                <span>${amount}x ${material} (${playerHas} available)</span>
            </div>
        `);
    }
    
    const levelSufficient = playerLevel >= repairCost.levelRequired;
    if (!levelSufficient) canRepair = false;
    
    materialsList.append(`
        <div class="material-item ${levelSufficient ? '' : 'insufficient'}">
            <i class="fas fa-star" style="color: #f1c40f; margin-right: 10px;"></i>
            <span>Level ${repairCost.levelRequired} Required (Current: ${playerLevel})</span>
        </div>
    `);
    
    const canRepairCondition = selectedWeapon.condition < 100;
    $('#repair-btn').prop('disabled', !canRepair || !canRepairCondition);
}
