import os
import re

icon_mapping = {
    'access_time': 'SolarIconsOutline.clockCircle',
    'access_time_filled_rounded': 'SolarIconsBold.clockCircle',
    'access_time_rounded': 'SolarIconsOutline.clockCircle',
    'account_balance': 'SolarIconsOutline.banknote',
    'account_balance_outlined': 'SolarIconsOutline.banknote',
    'account_balance_wallet': 'SolarIconsOutline.wallet',
    'account_balance_wallet_outlined': 'SolarIconsOutline.wallet',
    'add': 'SolarIconsOutline.addCircle',
    'add_a_photo_outlined': 'SolarIconsOutline.cameraAdd',
    'add_rounded': 'SolarIconsOutline.addCircle',
    'alarm': 'SolarIconsOutline.alarm',
    'arrow_back': 'SolarIconsOutline.altArrowLeft',
    'arrow_back_ios_new': 'SolarIconsOutline.altArrowLeft',
    'arrow_back_ios_new_rounded': 'SolarIconsOutline.altArrowLeft',
    'arrow_downward_rounded': 'SolarIconsOutline.altArrowDown',
    'arrow_forward_rounded': 'SolarIconsOutline.altArrowRight',
    'arrow_upward_rounded': 'SolarIconsOutline.altArrowUp',
    'auto_awesome': 'SolarIconsOutline.stars',
    'bar_chart_rounded': 'SolarIconsOutline.chart',
    'beach_access_outlined': 'SolarIconsOutline.umbrella',
    'call_outlined': 'SolarIconsOutline.phone',
    'camera_alt': 'SolarIconsOutline.camera',
    'camera_alt_outlined': 'SolarIconsOutline.camera',
    'camera_alt_rounded': 'SolarIconsOutline.camera',
    'cancel_outlined': 'SolarIconsOutline.closeCircle',
    'category_outlined': 'SolarIconsOutline.widget',
    'chair_outlined': 'SolarIconsOutline.armchair',
    'chat_bubble_outline': 'SolarIconsOutline.chatRound',
    'chat_bubble_outline_rounded': 'SolarIconsOutline.chatRound',
    'chat_bubble_rounded': 'SolarIconsBold.chatRound',
    'chat_outlined': 'SolarIconsOutline.chatRound',
    'check': 'SolarIconsOutline.checkRead',
    'check_circle_outline': 'SolarIconsOutline.checkCircle',
    'check_circle_rounded': 'SolarIconsOutline.checkCircle',
    'check_rounded': 'SolarIconsOutline.checkCircle',
    'chevron_right': 'SolarIconsOutline.altArrowRight',
    'chevron_right_rounded': 'SolarIconsOutline.altArrowRight',
    'close': 'SolarIconsOutline.closeSquare',
    'close_rounded': 'SolarIconsOutline.closeSquare',
    'cloud_upload_outlined': 'SolarIconsOutline.cloudUpload',
    'copy': 'SolarIconsOutline.copy',
    'delete_outline': 'SolarIconsOutline.trashBinTrash',
    'delivery_dining': 'SolarIconsOutline.routing',
    'description_outlined': 'SolarIconsOutline.document',
    'eco': 'SolarIconsOutline.leaf',
    'eco_outlined': 'SolarIconsOutline.leaf',
    'eco_rounded': 'SolarIconsOutline.leaf',
    'edit_outlined': 'SolarIconsOutline.pen',
    'email_outlined': 'SolarIconsOutline.letter',
    'error_outline': 'SolarIconsOutline.dangerCircle',
    'fastfood': 'SolarIconsOutline.hamburger',
    'fastfood_rounded': 'SolarIconsOutline.hamburger',
    'gps_fixed_rounded': 'SolarIconsOutline.mapPoint',
    'headset_mic_outlined': 'SolarIconsOutline.headphonesRound',
    'home_outlined': 'SolarIconsOutline.home2',
    'home_rounded': 'SolarIconsBold.home2',
    'hourglass_top': 'SolarIconsOutline.hourglass',
    'hourglass_top_rounded': 'SolarIconsOutline.hourglass',
    'image_not_supported': 'SolarIconsOutline.galleryRemove',
    'image_outlined': 'SolarIconsOutline.gallery',
    'info_outline': 'SolarIconsOutline.infoCircle',
    'info_outline_rounded': 'SolarIconsOutline.infoCircle',
    'inventory_2_outlined': 'SolarIconsOutline.box',
    'inventory_2_rounded': 'SolarIconsBold.box',
    'keyboard_arrow_down_rounded': 'SolarIconsOutline.altArrowDown',
    'keyboard_rounded': 'SolarIconsOutline.keyboard',
    'local_fire_department_rounded': 'SolarIconsOutline.fire',
    'local_offer_outlined': 'SolarIconsOutline.tag',
    'location_on': 'SolarIconsBold.mapPoint',
    'location_on_outlined': 'SolarIconsOutline.mapPoint',
    'location_on_rounded': 'SolarIconsOutline.mapPoint',
    'lock_outline_rounded': 'SolarIconsOutline.lockPassword',
    'logout_rounded': 'SolarIconsOutline.logout3',
    'lunch_dining_outlined': 'SolarIconsOutline.hamburger',
    'mail_outline_rounded': 'SolarIconsOutline.letter',
    'mark_email_unread_outlined': 'SolarIconsOutline.letterUnread',
    'mic_none_rounded': 'SolarIconsOutline.microphone',
    'moped': 'SolarIconsOutline.routing',
    'more_vert': 'SolarIconsOutline.menuDots',
    'notifications_active_outlined': 'SolarIconsOutline.bellBing',
    'notifications_none_rounded': 'SolarIconsOutline.bell',
    'notifications_outlined': 'SolarIconsOutline.bell',
    'payment': 'SolarIconsOutline.card',
    'person_add_alt_1_outlined': 'SolarIconsOutline.userPlus',
    'person_outline': 'SolarIconsOutline.user',
    'person_outline_rounded': 'SolarIconsOutline.user',
    'person_rounded': 'SolarIconsBold.user',
    'phone_android_rounded': 'SolarIconsOutline.smartphone',
    'phone_outlined': 'SolarIconsOutline.phone',
    'photo_library': 'SolarIconsOutline.gallery',
    'photo_library_outlined': 'SolarIconsOutline.gallery',
    'pie_chart_rounded': 'SolarIconsOutline.pieChart',
    'public': 'SolarIconsOutline.global',
    'qr_code_scanner': 'SolarIconsOutline.scanner',
    'receipt_long': 'SolarIconsOutline.bill',
    'receipt_long_outlined': 'SolarIconsOutline.bill',
    'receipt_long_rounded': 'SolarIconsOutline.bill',
    'remove': 'SolarIconsOutline.minusSquare',
    'remove_red_eye_outlined': 'SolarIconsOutline.eye',
    'search': 'SolarIconsOutline.magnifier',
    'search_off_rounded': 'SolarIconsOutline.magnifier',
    'search_rounded': 'SolarIconsOutline.magnifier',
    'sell_outlined': 'SolarIconsOutline.tag',
    'send_rounded': 'SolarIconsOutline.plain',
    'sentiment_satisfied_alt_rounded': 'SolarIconsOutline.smileCircle',
    'settings_outlined': 'SolarIconsOutline.settings',
    'share_outlined': 'SolarIconsOutline.share',
    'shopping_bag_outlined': 'SolarIconsOutline.bag',
    'shopping_basket_outlined': 'SolarIconsOutline.cart',
    'shopping_cart': 'SolarIconsOutline.cart',
    'star_border_rounded': 'SolarIconsOutline.star',
    'star_outline_rounded': 'SolarIconsOutline.star',
    'store': 'SolarIconsOutline.shop',
    'storefront': 'SolarIconsOutline.shop',
    'storefront_outlined': 'SolarIconsOutline.shop',
    'storefront_rounded': 'SolarIconsBold.shop',
    'support_agent': 'SolarIconsOutline.headphonesRound',
    'swap_horiz_rounded': 'SolarIconsOutline.transferHorizontal',
    'thumb_up_outlined': 'SolarIconsOutline.like',
    'timer_outlined': 'SolarIconsOutline.timer',
    'tune': 'SolarIconsOutline.tuner',
    'tune_rounded': 'SolarIconsOutline.tuner',
    'verified': 'SolarIconsOutline.verifiedCheck',
    'verified_rounded': 'SolarIconsOutline.verifiedCheck',
    'visibility_off_outlined': 'SolarIconsOutline.eyeClosed',
    'visibility_outlined': 'SolarIconsOutline.eye',
    'wallet_outlined': 'SolarIconsOutline.wallet',
}

def process_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content
    replaced = False

    def replacer(match):
        icon_name = match.group(1)
        if icon_name in icon_mapping:
            nonlocal replaced
            replaced = True
            return icon_mapping[icon_name]
        return match.group(0)

    new_content = re.sub(r'Icons\.([a-zA-Z0-9_]+)', replacer, content)

    if replaced:
        # Add import if not present
        if "import 'package:solar_icons/solar_icons.dart';" not in new_content:
            # find the last import and insert after it, or insert at the top
            import_statement = "import 'package:solar_icons/solar_icons.dart';\n"
            last_import_index = new_content.rfind("import '")
            if last_import_index != -1:
                end_of_last_import = new_content.find('\n', last_import_index) + 1
                new_content = new_content[:end_of_last_import] + import_statement + new_content[end_of_last_import:]
            else:
                new_content = import_statement + new_content

        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated: {file_path}")

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
