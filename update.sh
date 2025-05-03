#!/bin/sh

# 使用Python 3实现
# 清理旧文件（静默错误输出）
    rm Packages Packages.xz Packages.gz Packages.bz2 Packages.zst Release 2> /dev/null
    
    # 生成APT仓库元数据   https://apt.procurs.us/apt-ftparchive
    ./apt-ftparchive packages ./debfiles > Packages  # 创建软件包索引
    gzip -c9 Packages > Packages.gz    # GZIP压缩
    xz -c9 Packages > Packages.xz      # XZ压缩
    zstd -c19 Packages > Packages.zst  # Zstandard压缩
    bzip2 -c9 Packages > Packages.bz2  # BZIP2压缩
    
    # 生成Release文件
   # ./apt-ftparchive release -c ./repoinfo/repo.conf . > Release  
    
python3 <<EOF
import os
import json
import subprocess
from pathlib import Path

output = []
debfiles = sorted(Path('debfiles').glob('*.deb'), key=lambda x: x.stat().st_mtime, reverse=True)

for deb in debfiles:
    try:
        # 获取deb信息（强制UTF-8输出）
        result = subprocess.run(
            ['dpkg', '-f', str(deb), 'Package', 'Name', 'Version', 'Section', 'Description', 'Depends', 'Depiction', 'Author'],
            capture_output=True,
            text=True,
            encoding='utf-8',
            errors='replace'
        )
        
        # 解析字段
        info = {}
        for line in result.stdout.splitlines():
            if ':' in line:
                key, value = line.split(':', 1)
                info[key.strip()] = value.strip()
        
        # 构建条目
        entry = {
            "package": info.get('Package', ''),
            "name": info.get('Name', info.get('Package', '')),
            "version": info.get('Version', 'unknown'),
            "Description": info.get('Description', 'unknown'),
            "Depiction": info.get('Depiction', '未知主页'),
            "Depends": info.get('Depends', '~'),
            "Author": info.get('Author', '未知作者'),
            "section": info.get('Section', 'uncategorized'),
            "size": deb.stat().st_size,
            "time": int(deb.stat().st_mtime),
            "Filename": deb.name
        }
        output.append(entry)
        
    except Exception as e:
        print(f"处理文件 {deb.name} 失败: {str(e)}", file=sys.stderr)

# 生成格式化的JSON
with open('all.packages', 'w', encoding='utf-8') as f:
    json.dump(output, f, ensure_ascii=False, indent=2)

print("生成成功！共处理", len(output), "个软件包")
EOF

# 验证生成结果
if [ -f all.packages ]; then
    echo "验证JSON格式..."
    python3 -m json.tool all.packages > /dev/null && echo "格式验证通过"
else
    echo "生成失败，请检查Python错误信息"
fi
