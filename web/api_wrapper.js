class APIWrapper {
    uploadFile(url, file, onLoadStart, onProgress, onError, onLoadEnd) {
        if (!(typeof url === 'string' && typeof file === 'object')) throw Error('Invalid call');
        let formData = new FormData;
        formData.append('file_size', file.size);
        formData.append('file_upload', file, file.name);
        let xhr = new XMLHttpRequest;
        xhr.open('POST', url);
        xhr.addEventListener('progress', onProgress);
        xhr.addEventListener('error', onError);
        xhr.addEventListener('loadstart', onLoadStart);
        xhr.addEventListener('load', onLoadEnd);
        xhr.send(formData);
    }
}