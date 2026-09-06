"""Reviewed vocabulary and occurrence labels; original evidence remains visible."""
NAMES = {
 'egg': ['Egg', 'البيض', '蛋类', '卵'], 'milk': ['Milk / dairy', 'الحليب ومشتقاته', '乳及乳制品', '乳・乳製品'],
 'buckwheat': ['Buckwheat', 'الحنطة السوداء', '荞麦', 'そば'], 'peanut': ['Peanut', 'الفول السوداني', '花生', '落花生'],
 'soy': ['Soy', 'الصويا', '大豆', '大豆'], 'wheat': ['Wheat / gluten', 'القمح والغلوتين', '小麦／麸质', '小麦・グルテン'],
 'mackerel': ['Mackerel', 'الماكريل', '鲭鱼', 'さば'], 'crab': ['Crab', 'السلطعون', '蟹', 'かに'],
 'shrimp': ['Shrimp', 'الروبيان', '虾', 'えび'], 'crustacean': ['Crustaceans', 'القشريات', '甲壳类', '甲殻類'],
 'pork': ['Pork / pork-derived', 'لحم الخنزير ومشتقاته', '猪肉及猪源成分', '豚肉・豚由来成分'],
 'peach': ['Peach', 'الخوخ', '桃', 'もも'], 'tomato': ['Tomato', 'الطماطم', '番茄', 'トマト'],
 'sulfite': ['Sulfites', 'الكبريتيت', '亚硫酸盐', '亜硫酸塩'], 'walnut': ['Walnut', 'الجوز', '核桃', 'くるみ'],
 'chicken': ['Chicken', 'الدجاج', '鸡肉', '鶏肉'], 'beef': ['Beef', 'لحم البقر', '牛肉', '牛肉'],
 'squid': ['Squid', 'الحبار', '鱿鱼', 'いか'], 'shellfish': ['Shellfish', 'المحار', '贝类', '貝類'],
 'pine_nut': ['Pine nuts', 'الصنوبر', '松子', '松の実'], 'tree_nut': ['Tree nuts', 'المكسرات', '坚果', 'ナッツ類'],
 'fish': ['Fish', 'الأسماك', '鱼类', '魚類'], 'sesame': ['Sesame', 'السمسم', '芝麻', 'ごま'],
 'bacon_ham': ['Bacon / ham', 'لحم مقدد / هام', '培根／火腿', 'ベーコン・ハム'],
 'gelatin': ['Gelatin', 'الجيلاتين', '明胶', 'ゼラチン'], 'alcohol': ['Alcohol / spirits', 'الكحول', '酒精／酒类', 'アルコール・酒類'],
 'meat': ['Meat / meat-derived', 'اللحوم ومشتقاتها', '肉类及肉源成分', '肉類・肉由来成分'],
 'animal_fat': ['Animal fat / extract', 'دهون أو مستخلص حيواني', '动物脂肪／提取物', '動物性油脂・抽出物'],
 'additive': ['Additive: source needs checking', 'مضاف: يجب التحقق من المصدر', '添加剂：需确认来源', '添加物：由来の確認が必要'],
 'seafood': ['Seafood', 'المأكولات البحرية', '水产品', '魚介類'], 'honey': ['Honey', 'العسل', '蜂蜜', 'はちみつ'],
 'color': ['Animal-derived color / coating', 'ملون أو طلاء من أصل حيواني', '动物源色素／包衣', '動物由来色素・コーティング'],
 'meat_fish': ['Meat / fish', 'اللحوم والأسماك', '肉类／鱼类', '肉類・魚類'],
}
RULE_KEYS = {
 **{'allergy_'+key:key for key in ['egg','milk','buckwheat','peanut','soy','wheat','mackerel','crab','shrimp','pork','peach','tomato','sulfite','walnut','chicken','beef','squid','shellfish','pine_nut']},
 'allergy_crustacean_general':'crustacean','allergy_tree_nut_optional':'tree_nut','allergy_fish_optional':'fish','allergy_sesame_optional':'sesame',
 'halal_pork_direct':'pork','halal_bacon_ham_caution':'bacon_ham','halal_gelatin_unknown':'gelatin','halal_alcohol_caution':'alcohol',
 'halal_meat_uncertified':'meat','halal_animal_fat_unknown':'animal_fat','halal_processing_aid_unknown':'additive',
 'vegan_meat_direct':'meat','vegan_seafood_direct':'seafood','vegan_milk_direct':'milk','vegan_egg_direct':'egg','vegan_honey_direct':'honey',
 'vegan_gelatin_direct':'gelatin','vegan_color_additives_direct':'color','vegan_source_unknown_additives':'additive',
 'vegetarian_meat_fish':'meat_fish','vegetarian_gelatin_unknown':'gelatin',
}
OCCURRENCE = {
 'direct':['Ingredient declaration','مذكور ضمن المكونات','配料标示','原材料表示'],
 'cross_contact':['Possible cross-contact','احتمال تلامس عرضي','可能交叉接触','交差接触の可能性'],
 'unknown':['Context needs checking','يجب التحقق من السياق','需确认语境','文脈の確認が必要'],
}


def detection_text(detection, language):
    index = ['en','ar','zh','ja'].index(language)
    name = NAMES.get(RULE_KEYS.get(detection['rule_id']), [detection['canonical_name']]*4)[index]
    occurrence = OCCURRENCE.get(detection.get('occurrence_type'), OCCURRENCE['unknown'])[index]
    return f"{name} ({detection['matched_keyword']}) · {occurrence} · {detection['category'].upper()} · {detection['severity'].upper()}"
