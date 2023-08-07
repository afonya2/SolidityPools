local dw = {}
function dw.sendMessage(url, username, avatar, content, embeds)
    local json = {
        content = content,
        username = username,
        ["avatar_url"] = avatar,
        embeds = embeds
    }
    local data = http.post(url.."?wait=true", textutils.serialiseJSON(json), {["Content-Type"] = "application/json"})
    return textutils.unserialiseJSON(data.readAll())
end
function dw.editMessage(url, id, content, embeds)
    local json = {
        content = content,
        embeds = embeds
    }
    http.request({
        url = url.."/messages/"..id,
        body = textutils.serialiseJSON(json),
        headers = {["Content-Type"]="application/json"},
        method = "PATCH"
    })
end
function dw.createEmbed()
    local out = {
        title= "",
        color= "",
        description= "",
        fields= {},
        author= {},
        footer= {},
        timestamp= "",
        thumbnail= {}
    }
    function out:setTitle(title)
        out.title = title
        return out
    end
    function out:setDescription(description)
        out.description = description
        return out
    end
    function out:setColor(color)
        out.color = color
        return out
    end
    function out:addField(name, value, inline)
        table.insert(out.fields, {
            name = name,
            value = value,
            inline = inline
        })
        return out
    end
    function out:setAuthor(name, avatar)
        out.author = {
            name = name,
            ["icon_url"] = avatar
        }
        return out
    end
    function out:setFooter(text, avatar)
        out.footer = {
            text = text,
            ["icon_url"] = avatar
        }
        return out
    end
    function out:setTimestamp()
        local date = os.date("!%Y-%m-%dT%H:%M:%S.") .. string.format("%03d", (os.clock() * 1000)) .. "Z"
        out.timestamp = date
        return out
    end
    function out:setThumbnail(url)
        out.thumbnail = {
            url = url,
        }
        return out
    end
    function out:sendable()
        return {
            title = out.title,
            color = out.color,
            description = out.description,
            fields = out.fields,
            author = out.author,
            footer = out.footer,
            timestamp = out.timestamp,
            thumbnail = out.thumbnail
        }
    end
    return out
end
return dw